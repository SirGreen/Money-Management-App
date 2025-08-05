import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:test_app/app/controllers/expenditure_controller.dart';
import 'package:test_app/app/controllers/settings_controller.dart';
import 'package:test_app/app/helpers/currency_input_formatter.dart';
import 'package:test_app/app/models/expenditure.dart';
import 'package:test_app/app/models/tag.dart';
// import 'package:test_app/app/views/add_edit_tag_page.dart';
import 'package:test_app/app/views/helpers/glass_card.dart';
import 'package:test_app/app/views/helpers/gradient_background.dart';
import 'package:test_app/app/views/helpers/gradient_title.dart';
import 'package:test_app/app/views/helpers/section_header.dart';
import 'package:test_app/app/views/helpers/tag_icon.dart';
import 'package:test_app/app/views/helpers/currency_picker_sheet.dart';
import 'package:test_app/app/views/main_page.dart';
import 'package:test_app/l10n/app_localizations.dart';
import 'package:uuid/uuid.dart';

class AddEditExpenditureAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final AppLocalizations l10n;
  final bool isEditing;
  final VoidCallback? onDeletePressed;

  const AddEditExpenditureAppBar({
    super.key,
    required this.l10n,
    required this.isEditing,
    this.onDeletePressed,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: AppBar(
          title: GradientTitle(
            text: isEditing ? l10n.editTransaction : l10n.addTransaction,
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.white.withOpacity(0.2),
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(32),
            ),
            side: BorderSide(color: Colors.white.withOpacity(0.3)),
          ),
          actions: [
            if (isEditing)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: onDeletePressed,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class AddEditExpenditurePage extends StatefulWidget {
  final Expenditure? expenditure;
  final String? prefilledName;
  final double? prefilledAmount;
  final List<Tag>? prefilledTags;
  final String? prefilledReceiptPath;
  final String? prefilledMemo;

  const AddEditExpenditurePage({
    super.key,
    this.expenditure,
    this.prefilledName,
    this.prefilledAmount,
    this.prefilledTags,
    this.prefilledReceiptPath,
    this.prefilledMemo,
  });

  @override
  State<AddEditExpenditurePage> createState() => _AddEditExpenditurePageState();
}

class _AddEditExpenditurePageState extends State<AddEditExpenditurePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _amountController;
  late TextEditingController _notesController;
  late TextEditingController _additionalAmountController;
  late FocusNode _amountFocusNode;
  List<String> _amountSuggestions = [];
  late DateTime _selectedDate;
  String? _selectedMainTagId;
  late List<String> _selectedSubTagIds;
  bool _isIncome = false;
  List<Object> _recommendedItems = [];
  bool _isFetchingRecommendations = false;
  String? _receiptPath;
  File? _tempReceiptFile;
  String? _inputCurrency;
  double? _conversionRate;
  String _convertedAmountString = '';
  bool _isConverting = false;
  Timer? _debounce;
  bool get isEditing => widget.expenditure != null;
  bool _isAddingToTotal = true;

  @override
  void initState() {
    super.initState();
    final expenditure = widget.expenditure;
    final primaryCurrency = Provider.of<SettingsController>(
      context,
      listen: false,
    ).settings.primaryCurrencyCode;
    final formatter = NumberFormat('#,###');
    _amountFocusNode = FocusNode();
    _nameController = TextEditingController(
      text: widget.prefilledName ?? expenditure?.articleName ?? '',
    );
    final double? initialAmount = widget.prefilledAmount ?? expenditure?.amount;
    _amountController = TextEditingController(
      text: initialAmount != null ? formatter.format(initialAmount) : '',
    );
    _notesController = TextEditingController(
      text: widget.prefilledMemo ?? expenditure?.notes ?? '',
    );
    _additionalAmountController = TextEditingController();
    _selectedDate = expenditure?.date ?? DateTime.now();
    _isIncome = expenditure?.isIncome ?? false;
    _receiptPath = widget.prefilledReceiptPath ?? expenditure?.receiptImagePath;
    _inputCurrency = expenditure?.currencyCode ?? primaryCurrency;
    if (widget.prefilledTags != null && widget.prefilledTags!.isNotEmpty) {
      _selectedMainTagId = widget.prefilledTags![0].id;
      _selectedSubTagIds = widget.prefilledTags!.length > 1
          ? widget.prefilledTags!.sublist(1).map((t) => t.id).toList()
          : [];
    } else {
      _selectedMainTagId = expenditure?.mainTagId;
      _selectedSubTagIds = List.from(expenditure?.subTagIds ?? []);
    }
    if ((widget.prefilledAmount != null || expenditure?.amount == null)) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _amountFocusNode.requestFocus(),
      );
    }
    _amountController.addListener(_onAmountOrCurrencyChanged);
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountOrCurrencyChanged);
    _debounce?.cancel();
    _nameController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    _additionalAmountController.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  void _adjustTotalAmount() {
    final l10n = AppLocalizations.of(context)!;
    final currentAmount =
        double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0.0;
    final additionalAmount =
        double.tryParse(_additionalAmountController.text.replaceAll(',', '')) ??
        0.0;

    if (additionalAmount <= 0) return;

    double newTotal;
    if (_isAddingToTotal) {
      newTotal = currentAmount + additionalAmount;
    } else {
      newTotal = currentAmount - additionalAmount;
      if (newTotal < 0) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.cannotBeNegative)));
        return;
      }
    }

    final formatter = NumberFormat.decimalPattern(l10n.localeName);
    final String formattedTotal = formatter.format(newTotal);

    setState(() {
      _amountController.text = formattedTotal;
      _additionalAmountController.clear();
    });

    _onAmountOrCurrencyChanged();
    FocusScope.of(context).unfocus();
  }

  void _onAmountOrCurrencyChanged() {
    _updateAmountSuggestions();
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _convertAmount);
  }

  Future<void> _convertAmount() async {
    final primaryCurrency = Provider.of<SettingsController>(
      context,
      listen: false,
    ).settings.primaryCurrencyCode;
    if (_inputCurrency == primaryCurrency || _amountController.text.isEmpty) {
      if (mounted) {
        setState(() {
          _convertedAmountString = '';
          _isConverting = false;
        });
      }
      return;
    }
    if (mounted) setState(() => _isConverting = true);
    final controller = Provider.of<ExpenditureController>(
      context,
      listen: false,
    );
    final rate = await controller.getBestExchangeRate(
      _inputCurrency!,
      primaryCurrency,
    );
    if (mounted) {
      setState(() {
        _conversionRate = rate;
        final amount = double.tryParse(
          _amountController.text.replaceAll(',', ''),
        );
        if (rate != null && amount != null) {
          final converted = amount * rate;
          _convertedAmountString =
              '≈ ${NumberFormat.currency(name: primaryCurrency).format(converted)}';
        } else {
          _convertedAmountString = 'Rate not found';
        }
        _isConverting = false;
      });
    }
  }

  void _updateAmountSuggestions() {
    final text = _amountController.text.replaceAll(',', '');
    final amount = double.tryParse(text);
    if (amount == null || amount == 0 || text.contains('.')) {
      if (_amountSuggestions.isNotEmpty) {
        setState(() => _amountSuggestions = []);
      }
      return;
    }
    if (amount > 1000000) {
      if (_amountSuggestions.isNotEmpty) {
        setState(() => _amountSuggestions = []);
      }
      return;
    }
    final integerText = amount.toInt().toString();
    final newSuggestions = ['${integerText}000', '${integerText}0000'];
    setState(() => _amountSuggestions = newSuggestions);
  }

  void _applyAmountSuggestion(String suggestion) {
    final l10n = AppLocalizations.of(context)!;
    final int number = int.parse(suggestion);
    final formatter = NumberFormat.decimalPattern(l10n.localeName);
    final String formattedSuggestion = formatter.format(number);
    _amountController.text = formattedSuggestion;
    _amountController.selection = TextSelection.fromPosition(
      TextPosition(offset: _amountController.text.length),
    );
    setState(() => _amountSuggestions = []);
  }

  Future<void> _getRecommendations() async {
    final l10n = AppLocalizations.of(context)!;
    if (_nameController.text.length < 3) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.enterMoreCharsForSuggestion)),
        );
      }
      return;
    }
    if (_isFetchingRecommendations) return;
    if (mounted) {
      setState(() {
        _isFetchingRecommendations = true;
        _recommendedItems = [];
      });
    }
    final controller = Provider.of<ExpenditureController>(
      context,
      listen: false,
    );
    final recommendations = await controller.recommendTags(
      _nameController.text,
    );
    if (mounted) {
      setState(() {
        _recommendedItems = recommendations;
        _isFetchingRecommendations = false;
      });
    }
  }

  Future<void> _applyRecommendation(Object recommendation) async {
    final expenditureController = Provider.of<ExpenditureController>(
      context,
      listen: false,
    );

    String? tagIdToApply;
    if (recommendation is String) {
      tagIdToApply = const Uuid().v4();
      await expenditureController.addTag(
        id: tagIdToApply,
        name: recommendation,
        colorValue: Colors.grey.value,
        iconName: 'label',
      );
    } else if (recommendation is Tag) {
      tagIdToApply = recommendation.id;
    }
    if (tagIdToApply == null || !mounted) return;
    setState(() {
      _handleTagSelection(tagIdToApply!, true);
      _recommendedItems.remove(recommendation);
    });
  }

  Future<void> _saveForm() async {
    final l10n = AppLocalizations.of(context)!;
    final expenditureController = Provider.of<ExpenditureController>(
      context,
      listen: false,
    );
    final settings = Provider.of<SettingsController>(
      context,
      listen: false,
    ).settings;
    if (_nameController.text.isEmpty) {
      final date = DateFormat.Hms(l10n.localeName).format(_selectedDate);
      _nameController.text = 'Default - $date';
    }
    if (_selectedMainTagId == null) {
      if (_isIncome) {
        final incomeTag = expenditureController.tags.firstWhere(
          (t) => t.id == 'income',
          orElse: () => expenditureController.tags.first,
        );
        _selectedMainTagId = incomeTag.id;
      } else {
        _selectedMainTagId = ExpenditureController.defaultTagId;
      }
    }
    String? finalReceiptPath = _receiptPath;
    if (_tempReceiptFile != null) {
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = path.basename(_tempReceiptFile!.path);
        final savedImage = await _tempReceiptFile!.copy(
          '${appDir.path}/$fileName',
        );
        finalReceiptPath = savedImage.path;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.imageSaveFailed(e))));
        }
        return;
      }
    }
    double? finalAmount;
    final amountInput = double.tryParse(
      _amountController.text.replaceAll(',', ''),
    );
    if (amountInput != null) {
      if (_inputCurrency == settings.primaryCurrencyCode ||
          _conversionRate == null) {
        finalAmount = amountInput;
      } else {
        finalAmount = amountInput * _conversionRate!;
      }
    }
    if (isEditing) {
      final updatedExpenditure = widget.expenditure!;
      updatedExpenditure.articleName = _nameController.text;
      updatedExpenditure.amount = finalAmount;
      updatedExpenditure.date = _selectedDate;
      updatedExpenditure.mainTagId = _selectedMainTagId!;
      updatedExpenditure.subTagIds = _selectedSubTagIds;
      updatedExpenditure.isIncome = _isIncome;
      updatedExpenditure.notes = _notesController.text;
      updatedExpenditure.receiptImagePath = finalReceiptPath;
      updatedExpenditure.currencyCode = settings.primaryCurrencyCode;
      updatedExpenditure.updatedAt = DateTime.now();
      expenditureController.updateExpenditure(settings, updatedExpenditure);
    } else {
      expenditureController.addExpenditure(
        settings,
        articleName: _nameController.text,
        amount: finalAmount,
        date: _selectedDate,
        mainTagId: _selectedMainTagId!,
        subTagIds: _selectedSubTagIds,
        isIncome: _isIncome,
        notes: _notesController.text,
        receiptImagePath: finalReceiptPath,
      );
    }

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const MainPage(initialIndex: 1),
        ),
        (Route<dynamic> route) => false,
      );
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickReceiptImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _tempReceiptFile = File(pickedFile.path);
        _receiptPath = null;
      });
    }
  }

  void _handleTagSelection(String tagId, bool isSelected) {
    setState(() {
      if (isSelected) {
        if (_selectedMainTagId == null) {
          _selectedMainTagId = tagId;
        } else if (!_selectedSubTagIds.contains(tagId)) {
          _selectedSubTagIds.add(tagId);
        }
      } else {
        if (_selectedMainTagId == tagId) {
          _selectedMainTagId = _selectedSubTagIds.isNotEmpty
              ? _selectedSubTagIds.removeAt(0)
              : null;
        } else {
          _selectedSubTagIds.remove(tagId);
        }
      }
    });
  }

  void _clearAllTags() => setState(() {
    _selectedMainTagId = null;
    _selectedSubTagIds.clear();
  });

  void _showDeleteConfirmation(AppLocalizations l10n) {
    final settings = Provider.of<SettingsController>(
      context,
      listen: false,
    ).settings;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmDelete),
        content: Text(l10n.confirmDeleteMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Provider.of<ExpenditureController>(
                context,
                listen: false,
              ).deleteExpenditure(settings, widget.expenditure!.id);
              Navigator.of(ctx).pop(); 
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const MainPage(initialIndex: 1),
                ),
                (Route<dynamic> route) => false,
              );
            },
            child: Text(
              l10n.delete,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final addEditAppBar = AddEditExpenditureAppBar(
      l10n: l10n,
      isEditing: isEditing,
      onDeletePressed: () => _showDeleteConfirmation(l10n),
    );
    final double appBarHeight = addEditAppBar.preferredSize.height;
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double totalTopOffset = appBarHeight + statusBarHeight;

    return BackGround(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: addEditAppBar,
        body: Form(
          key: _formKey,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, totalTopOffset + 16, 16, 120),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildPrimaryInfoCard(context, l10n),
                    if (isEditing && !_isIncome) ...[
                      const SizedBox(height: 16),
                      _buildAddAmountSection(l10n),
                    ],
                    const SizedBox(height: 24),
                    Center(child: _buildTypeSelector(context, l10n)),
                    const SizedBox(height: 24),
                    _buildTagSelector(context, l10n),
                    const SizedBox(height: 24),
                    _buildDetailsSection(context, l10n),
                    if (isEditing) ...[
                      const SizedBox(height: 16),
                      _buildTimestampsCard(context, widget.expenditure!),
                    ],
                  ]),
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _saveForm,
          label: Text(isEditing ? l10n.update : l10n.save),
          icon: const Icon(Icons.check_rounded),
          backgroundColor: _isIncome
              ? Colors.green.shade400
              : Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  Widget _buildPrimaryInfoCard(BuildContext context, AppLocalizations l10n) {
    final currencySymbol = NumberFormat.simpleCurrency(
      name: _inputCurrency,
    ).currencySymbol;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      color: _isIncome ? Colors.green.withOpacity(0.2) : null,
      child: Column(
        children: [
          TextFormField(
            controller: _amountController,
            focusNode: _amountFocusNode,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: _isIncome
                  ? Colors.green.shade700
                  : Theme.of(context).colorScheme.onSurface,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: '0',
              prefixText: '$currencySymbol ',
              prefixStyle: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.normal,
                color: Colors.grey.shade600,
              ),
              counterText: '',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) =>
                (v != null &&
                    v.isNotEmpty &&
                    double.tryParse(v.replaceAll(',', '')) == null)
                ? l10n.validNumber
                : null,
            inputFormatters: [
              DecimalCurrencyInputFormatter(locale: l10n.localeName),
            ],
            maxLength: 15,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () async {
                  final selected = await showModalBottomSheet<String>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => CurrencyPickerSheet(
                      supportedCurrencies: currencyFlags.keys.toList(),
                      title: l10n.selectCurrency,
                    ),
                  );
                  if (selected != null && selected != _inputCurrency) {
                    setState(() {
                      _inputCurrency = selected;
                      _onAmountOrCurrencyChanged();
                    });
                  }
                },
                icon: Text(
                  currencyFlags[_inputCurrency] ?? '🏳️',
                  style: const TextStyle(fontSize: 18),
                ),
                label: Text(_inputCurrency ?? '...'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
              if (_isConverting)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (_convertedAmountString.isNotEmpty)
                Text(
                  _convertedAmountString,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade700),
                ),
            ],
          ),
          const Divider(height: 24),
          TextFormField(
            controller: _nameController,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: _isIncome ? l10n.source : l10n.articleName,
              border: InputBorder.none,
              hintStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade500,
              ),
            ),
            validator: (v) => v == null || v.isEmpty ? l10n.nameInput : null,
          ),
          if (_amountSuggestions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Wrap(
                spacing: 8.0,
                alignment: WrapAlignment.center,
                children: _amountSuggestions.map((suggestion) {
                  final formatted = NumberFormat.decimalPattern(
                    l10n.localeName,
                  ).format(int.parse(suggestion));
                  return ActionChip(
                    label: Text(formatted),
                    onPressed: () => _applyAmountSuggestion(suggestion),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTypeSelector(BuildContext context, AppLocalizations l10n) {
    return SegmentedButton<bool>(
      segments: [
        ButtonSegment<bool>(
          value: false,
          label: Text(l10n.expense),
          icon: const Icon(Icons.arrow_downward_rounded),
        ),
        ButtonSegment<bool>(
          value: true,
          label: Text(l10n.income),
          icon: const Icon(Icons.arrow_upward_rounded),
        ),
      ],
      selected: {_isIncome},
      onSelectionChanged: (newSelection) =>
          setState(() => _isIncome = newSelection.first),
      style: SegmentedButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.2),
        foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
        selectedBackgroundColor: _isIncome
            ? Colors.green.withOpacity(0.4)
            : Colors.white.withOpacity(0.5),
        selectedForegroundColor: _isIncome
            ? Colors.white
            : Theme.of(context).colorScheme.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
    );
  }

  Widget _buildTagSelector(BuildContext context, AppLocalizations l10n) {
    final controller = Provider.of<ExpenditureController>(context);
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: l10n.tags),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (controller.tags.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Text(
                        l10n.noTagsYet,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: controller.tags.map((tag) {
                      final isSelected =
                          _selectedMainTagId == tag.id ||
                          _selectedSubTagIds.contains(tag.id);
                      final isMain = _selectedMainTagId == tag.id;
                      return FilterChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(tag.name),
                            if (isMain) ...[
                              const SizedBox(width: 6),
                              Icon(
                                Icons.star_rounded,
                                size: 16,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ],
                          ],
                        ),
                        avatar: TagIcon(tag: tag, radius: 10),
                        selected: isSelected,
                        onSelected: (selected) =>
                            _handleTagSelection(tag.id, selected),
                        selectedColor: tag.color.withOpacity(0.25),
                        shape: StadiumBorder(
                          side: BorderSide(
                            color: isSelected
                                ? Colors.transparent
                                : Colors.white.withOpacity(0.4),
                          ),
                        ),
                        showCheckmark: false,
                      );
                    }).toList(),
                  ),
                if (_selectedMainTagId != null || !_isFetchingRecommendations)
                  const Divider(height: 24),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: [
                    if (_selectedMainTagId != null)
                      TextButton.icon(
                        icon: const Icon(Icons.layers_clear_outlined, size: 18),
                        label: Text(l10n.clearTags),
                        onPressed: _clearAllTags,
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    TextButton.icon(
                      icon: const Icon(Icons.lightbulb_outline, size: 18),
                      label: Text(l10n.suggestTags),
                      onPressed: _isFetchingRecommendations
                          ? null
                          : _getRecommendations,
                    ),
                  ],
                ),
                if (_isFetchingRecommendations)
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: LinearProgressIndicator(),
                  ),
                if (!_isFetchingRecommendations && _recommendedItems.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${l10n.recommendations}:",
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8.0,
                          runSpacing: 4.0,
                          children: _recommendedItems.map((item) {
                            if (item is Tag) {
                              return ActionChip(
                                avatar: TagIcon(tag: item, radius: 10),
                                label: Text(item.name),
                                onPressed: () => _applyRecommendation(item),
                              );
                            }
                            if (item is String) {
                              return ActionChip(
                                avatar: const Icon(
                                  Icons.add,
                                  size: 16,
                                  color: Colors.green,
                                ),
                                label: Text(item),
                                labelStyle: const TextStyle(
                                  fontStyle: FontStyle.italic,
                                ),
                                onPressed: () => _applyRecommendation(item),
                              );
                            }
                            return const SizedBox.shrink();
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddAmountSection(AppLocalizations l10n) {
    final currencySymbol = NumberFormat.simpleCurrency(
      name: _inputCurrency,
    ).currencySymbol;

    return GlassCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        leading: const Icon(Icons.add_shopping_cart_outlined),
        title: Text(l10n.adjustTotal), 
        subtitle: Text(l10n.forgotToAddItem),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _additionalAmountController,
                        decoration: InputDecoration(
                          labelText: l10n.adjustmentAmount, 
                          prefixText: '$currencySymbol ',
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.5),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          DecimalCurrencyInputFormatter(
                            locale: l10n.localeName,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    ToggleButtons(
                      isSelected: [_isAddingToTotal, !_isAddingToTotal],
                      onPressed: (index) {
                        setState(() {
                          _isAddingToTotal = index == 0;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      children: const [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12.0),
                          child: Icon(Icons.add),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12.0),
                          child: Icon(Icons.remove),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _adjustTotalAmount,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: _isAddingToTotal
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.error,
                    ),
                    child: Text(
                      _isAddingToTotal ? l10n.addToTotal : l10n.removeFromTotal,
                      style: TextStyle(color: Colors.white70, fontSize: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection(BuildContext context, AppLocalizations l10n) {
    final imageToShow = _tempReceiptFile != null
        ? FileImage(_tempReceiptFile!)
        : (_receiptPath != null ? FileImage(File(_receiptPath!)) : null);
    return GlassCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        title: Text(l10n.optionalDetails),
        leading: const Icon(Icons.notes_outlined),
        initiallyExpanded:
            _notesController.text.isNotEmpty || imageToShow != null,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: _pickDate,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.date,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        Row(
                          children: [
                            Text(
                              DateFormat.yMMMd(
                                l10n.localeName,
                              ).format(_selectedDate),
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.calendar_today,
                              size: 18,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    labelText: l10n.notes,
                    hintText: l10n.notesHint,
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.5),
                  ),
                  maxLines: 3,
                  minLines: 3,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.receipt,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 8),
                Card(
                  clipBehavior: Clip.antiAlias,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.white.withOpacity(0.5)),
                  ),
                  color: Colors.black.withOpacity(0.05),
                  child: InkWell(
                    onTap: imageToShow != null
                        ? () => showDialog(
                            context: context,
                            builder: (_) =>
                                Dialog(child: Image(image: imageToShow)),
                          )
                        : _pickReceiptImage,
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      decoration: imageToShow != null
                          ? BoxDecoration(
                              image: DecorationImage(
                                image: imageToShow,
                                fit: BoxFit.cover,
                              ),
                            )
                          : null,
                      child: imageToShow == null
                          ? Center(
                              child: Icon(
                                Icons.add_a_photo_outlined,
                                color: Colors.grey.shade600,
                                size: 40,
                              ),
                            )
                          : Align(
                              alignment: Alignment.bottomRight,
                              child: Container(
                                margin: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      onPressed: () => setState(() {
                                        _tempReceiptFile = null;
                                        _receiptPath = null;
                                      }),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      onPressed: _pickReceiptImage,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimestampsCard(BuildContext context, Expenditure expenditure) {
    final l10n = AppLocalizations.of(context)!;
    final locale = l10n.localeName;
    final formatter = DateFormat.yMMMd(locale).add_jm();
    return GlassCard(
      padding: EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.createdOn,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              Text(
                formatter.format(expenditure.createdAt),
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.lastUpdated,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              Text(
                formatter.format(expenditure.updatedAt),
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
