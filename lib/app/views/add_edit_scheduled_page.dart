import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:test_app/app/controllers/expenditure_controller.dart';
import 'package:test_app/app/controllers/settings_controller.dart';
import 'package:test_app/app/helpers/currency_input_formatter.dart';
import 'package:test_app/app/models/scheduled_expenditure.dart';
import 'package:test_app/app/models/tag.dart';
import 'package:test_app/app/views/add_edit_tag_page.dart';
import 'package:test_app/app/views/helpers/glass_card.dart';
import 'package:test_app/app/views/helpers/gradient_background.dart';
import 'package:test_app/app/views/helpers/gradient_title.dart';
import 'package:test_app/app/views/helpers/section_header.dart';
import 'package:test_app/app/views/helpers/tag_icon.dart';
import 'package:test_app/l10n/app_localizations.dart';
import 'package:uuid/uuid.dart';

class AddEditScheduledAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final AppLocalizations l10n;
  final bool isEditing;
  final VoidCallback? onDeletePressed;

  const AddEditScheduledAppBar({
    super.key,
    required this.l10n,
    required this.isEditing,
    this.onDeletePressed,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: AppBar(
          title: GradientTitle(
            text: isEditing ? l10n.editAutoTrans : l10n.addAutoTrans,
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

class AddEditScheduledPage extends StatefulWidget {
  final ScheduledExpenditure? scheduledExpenditure;
  const AddEditScheduledPage({super.key, this.scheduledExpenditure});

  @override
  State<AddEditScheduledPage> createState() => _AddEditScheduledPageState();
}

class _AddEditScheduledPageState extends State<AddEditScheduledPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _amountController;
  late TextEditingController _scheduleValueController;

  String? _selectedMainTagId;
  late List<String> _selectedSubTagIds;
  double? _initialAmount;
  bool _isIncome = false;

  ScheduleType _scheduleType = ScheduleType.dayOfMonth;
  late DateTime _startDate;
  DateTime? _endDate;

  List<Object> _recommendedItems = [];
  bool _isFetchingRecommendations = false;

  bool get isEditing => widget.scheduledExpenditure != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      final rule = widget.scheduledExpenditure!;
      _nameController = TextEditingController(text: rule.name);
      _amountController = TextEditingController(
        text: rule.amount?.toStringAsFixed(2).replaceAll('.', ',') ?? '',
      );
      _selectedMainTagId = rule.mainTagId;
      _selectedSubTagIds = List.from(rule.subTagIds);
      _scheduleType = rule.scheduleType;
      _startDate = rule.startDate;
      _endDate = rule.endDate;
      _scheduleValueController = TextEditingController(
        text: rule.scheduleValue.toString(),
      );
      _initialAmount = rule.amount;
      _isIncome = rule.isIncome;
    } else {
      _nameController = TextEditingController();
      _amountController = TextEditingController();
      _selectedMainTagId = null;
      _selectedSubTagIds = [];
      _scheduleType = ScheduleType.dayOfMonth;
      _startDate = DateTime.now();
      _endDate = null;
      _scheduleValueController = TextEditingController(text: '1');
      _isIncome = false;
      _initialAmount = null;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _scheduleValueController.dispose();
    super.dispose();
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

  Future<void> _handleDelete() async {
    if (!isEditing) return;
    final expenditureController = Provider.of<ExpenditureController>(
      context,
      listen: false,
    );
    final settings = Provider.of<SettingsController>(
      context,
      listen: false,
    ).settings;
    final rule = widget.scheduledExpenditure!;
    final l10n = AppLocalizations.of(context)!;

    final bool? shouldDeleteInstances = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.applyForRelatedTransaction),
        content: Text(l10n.confirmDeleteRuleInstance),
        actions: [
          TextButton(
            child: Text(l10n.leaveUnchanged),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.changeAll),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (shouldDeleteInstances == null || !mounted) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.finalConfirm),
        content: Text(
          shouldDeleteInstances
              ? l10n.confirmShouldDeleteInstance
              : l10n.confirmDeleteOnlyRule,
        ),
        actions: [
          TextButton(
            child: Text(l10n.cancel),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.performDeleteion),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await expenditureController.deleteScheduledExpenditure(
        settings,
        rule.id,
        deleteInstances: shouldDeleteInstances,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
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

  void _saveForm() {
    if (!_formKey.currentState!.validate() || _selectedMainTagId == null) {
      if (_selectedMainTagId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.selectMainTag)),
        );
      }
      return;
    }

    final expenditureController = Provider.of<ExpenditureController>(
      context,
      listen: false,
    );
    final settings = Provider.of<SettingsController>(
      context,
      listen: false,
    ).settings;

    final scheduleValue = int.tryParse(_scheduleValueController.text) ?? 1;
    final amountValue = _amountController.text.isEmpty
        ? null
        : double.tryParse(_amountController.text.replaceAll(',', ''));

    if (isEditing) {
      final ruleToUpdate = widget.scheduledExpenditure!;
      ruleToUpdate.name = _nameController.text;
      ruleToUpdate.amount = amountValue;
      ruleToUpdate.mainTagId = _selectedMainTagId!;
      ruleToUpdate.subTagIds = _selectedSubTagIds;
      ruleToUpdate.scheduleType = _scheduleType;
      ruleToUpdate.scheduleValue = scheduleValue;
      ruleToUpdate.startDate = _startDate;
      ruleToUpdate.endDate = _endDate;
      ruleToUpdate.isIncome = _isIncome;
      ruleToUpdate.currencyCode = widget.scheduledExpenditure!.currencyCode;

      final bool amountChanged = _initialAmount != amountValue;
      if (amountChanged) {
        _showAmountChangeDialog(ruleToUpdate);
      } else {
        expenditureController.updateScheduledExpenditure(
          settings,
          ruleToUpdate,
          updatePastAmounts: false,
        );
        Navigator.of(context).pop();
      }
    } else {
      final newRule = ScheduledExpenditure(
        id: const Uuid().v4(),
        name: _nameController.text,
        amount: amountValue,
        mainTagId: _selectedMainTagId!,
        subTagIds: _selectedSubTagIds,
        isIncome: _isIncome,
        scheduleType: _scheduleType,
        scheduleValue: scheduleValue,
        startDate: _startDate,
        endDate: _endDate,
        isActive: true,
        currencyCode: settings.primaryCurrencyCode,
      );
      expenditureController.addScheduledExpenditure(settings, newRule);
      Navigator.of(context).pop();
    }
  }

  void _showAmountChangeDialog(ScheduledExpenditure ruleToUpdate) {
    final expenditureController = Provider.of<ExpenditureController>(
      context,
      listen: false,
    );
    final settings = Provider.of<SettingsController>(
      context,
      listen: false,
    ).settings;
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.amountChanged),
        content: Text(l10n.confirmUpdateAllExpenses),
        actions: [
          TextButton(
            child: Text(l10n.noChange),
            onPressed: () {
              expenditureController.updateScheduledExpenditure(
                settings,
                ruleToUpdate,
                updatePastAmounts: false,
              );
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: Text(l10n.updateAll),
            onPressed: () {
              expenditureController.updateScheduledExpenditure(
                settings,
                ruleToUpdate,
                updatePastAmounts: true,
              );
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  void _handleTagSelection(String tagId, bool isSelected) {
    setState(() {
      if (isSelected) {
        if (_selectedMainTagId == null) {
          _selectedMainTagId = tagId;
        } else {
          _selectedSubTagIds.add(tagId);
        }
      } else {
        if (_selectedMainTagId == tagId) {
          if (_selectedSubTagIds.isNotEmpty) {
            _selectedMainTagId = _selectedSubTagIds.removeAt(0);
          } else {
            _selectedMainTagId = null;
          }
        } else {
          _selectedSubTagIds.remove(tagId);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheduledAppBar = AddEditScheduledAppBar(
      l10n: l10n,
      isEditing: isEditing,
      onDeletePressed: _handleDelete,
    );
    final double appBarHeight = scheduledAppBar.preferredSize.height;
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double totalTopOffset = appBarHeight + statusBarHeight;

    return BackGround(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: scheduledAppBar,
        body: Form(
          key: _formKey,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, totalTopOffset + 16, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildMainInfoCard(l10n),
                    const SizedBox(height: 24),
                    Center(child: _buildTypeSelector(l10n)),
                    const SizedBox(height: 24),
                    _buildTagsCard(l10n),
                    const SizedBox(height: 16),
                    _buildScheduleCard(l10n),
                  ]),
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _saveForm,
          label: Text(isEditing ? l10n.update : l10n.save),
          icon: const Icon(Icons.check),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  Widget _buildMainInfoCard(AppLocalizations l10n) {
    final settings = Provider.of<SettingsController>(
      context,
      listen: false,
    ).settings;
    final currencySymbol = NumberFormat.simpleCurrency(
      name: settings.primaryCurrencyCode,
    ).currencySymbol;
    return GlassCard(
      padding: const EdgeInsets.all(12),
      color: _isIncome
          ? Colors.green.withOpacity(0.2)
          : Colors.white.withOpacity(0.4),
      child: Column(
        children: [
          TextFormField(
            controller: _nameController,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              
              labelText: l10n.ruleName,
              border: InputBorder.none,
              floatingLabelBehavior: FloatingLabelBehavior.always,
              hintText: l10n.ruleName,
            ),
            validator: (v) => v == null || v.isEmpty ? l10n.nameInput : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _amountController,
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
              prefixText: currencySymbol,
              prefixStyle: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(color: Colors.grey.shade400),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) =>
                (value != null &&
                    value.isNotEmpty &&
                    double.tryParse(value.replaceAll(',', '')) == null)
                ? l10n.validNumber
                : null,
            inputFormatters: [
              DecimalCurrencyInputFormatter(locale: l10n.localeName),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSelector(AppLocalizations l10n) {
    return SegmentedButton<bool>(
      segments: [
        ButtonSegment<bool>(
          value: false,
          label: Text(l10n.expense),
          icon: const Icon(Icons.arrow_downward),
        ),
        ButtonSegment<bool>(
          value: true,
          label: Text(l10n.income),
          icon: const Icon(Icons.arrow_upward),
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
      ),
    );
  }

  Widget _buildTagsCard(AppLocalizations l10n) {
    final controller = Provider.of<ExpenditureController>(context);
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: l10n.tags),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: controller.tags.map((tag) {
                    final isSelected =
                        _selectedMainTagId == tag.id ||
                        _selectedSubTagIds.contains(tag.id);
                    final isMain = _selectedMainTagId == tag.id;
                    Widget labelWidget = Text(tag.name);
                    if (isMain) {
                      labelWidget = Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(tag.name),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.star,
                            size: 14,
                            color: tag.color.withOpacity(0.8),
                          ),
                        ],
                      );
                    }
                    return FilterChip(
                      label: labelWidget,
                      avatar: TagIcon(tag: tag, radius: 12),
                      selected: isSelected,
                      onSelected: (selected) =>
                          _handleTagSelection(tag.id, selected),
                      selectedColor: tag.color.withOpacity(0.25),
                      checkmarkColor: tag.color,
                      shape: StadiumBorder(
                        side: BorderSide(
                          color: isSelected
                              ? Colors.transparent
                              : Colors.white.withOpacity(0.4),
                        ),
                      ),
                      backgroundColor: Colors.black.withOpacity(0.1),
                    );
                  }).toList(),
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.lightbulb_outline, size: 18),
                      label: Text(l10n.suggestTags),
                      onPressed: _isFetchingRecommendations
                          ? null
                          : _getRecommendations,
                    ),
                    const SizedBox(width: 8),
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 18),
                      label: Text(l10n.addNewTag),
                      onPressed: () async => await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AddEditTagPage(),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_isFetchingRecommendations)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
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
                          style: const TextStyle(color: Colors.grey),
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

  Widget _buildScheduleCard(AppLocalizations l10n) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: l10n.repeatSetting),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                DropdownButtonFormField<ScheduleType>(
                  value: _scheduleType,
                  decoration: InputDecoration(
                    labelText: l10n.repeatType,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: ScheduleType.dayOfMonth,
                      child: Text(l10n.dayOfMonth),
                    ),
                    DropdownMenuItem(
                      value: ScheduleType.endOfMonth,
                      child: Text(l10n.endOfMonth),
                    ),
                    DropdownMenuItem(
                      value: ScheduleType.daysBeforeEndOfMonth,
                      child: Text(l10n.daysBeforeEoM),
                    ),
                    DropdownMenuItem(
                      value: ScheduleType.fixedInterval,
                      child: Text(l10n.fixedInterval),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _scheduleType = value;
                      _scheduleValueController.text = '1';
                      if (value == ScheduleType.fixedInterval)
                        _scheduleValueController.text = '30';
                    });
                  },
                ),
                const SizedBox(height: 16),
                if (_scheduleType != ScheduleType.endOfMonth)
                  _buildScheduleValueField(l10n),
                const SizedBox(height: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDateInput(l10n, l10n.startDate, _startDate, () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _startDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() {
                          _startDate = picked;
                          if (_endDate != null &&
                              _endDate!.isBefore(_startDate))
                            _endDate = null;
                        });
                      }
                    }),
                    const SizedBox(height: 16),
                    _buildDateInput(
                      l10n,
                      l10n.endDate,
                      _endDate,
                      () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _endDate ?? _startDate,
                          firstDate: _startDate,
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) setState(() => _endDate = picked);
                      },
                      onClear: _endDate == null
                          ? null
                          : () => setState(() => _endDate = null),
                      hintText: l10n.optional,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleValueField(AppLocalizations l10n) {
    switch (_scheduleType) {
      case ScheduleType.dayOfMonth:
        return DropdownButtonFormField<int>(
          value: int.tryParse(_scheduleValueController.text) ?? 1,
          decoration: InputDecoration(
            labelText: l10n.date,
            border: const OutlineInputBorder(),
          ),
          items: List.generate(28, (i) => i + 1)
              .map(
                (day) => DropdownMenuItem(
                  value: day,
                  child: Text(l10n.dayOfMonthLabel(day)),
                ),
              )
              .toList(),
          onChanged: (value) =>
              setState(() => _scheduleValueController.text = value.toString()),
        );
      case ScheduleType.daysBeforeEndOfMonth:
      case ScheduleType.fixedInterval:
        return TextFormField(
          controller: _scheduleValueController,
          decoration: InputDecoration(
            labelText: _scheduleType == ScheduleType.fixedInterval
                ? l10n.intervalDays
                : l10n.howManyDaysBefore,
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (v) => (v == null || v.isEmpty || int.parse(v) < 1)
              ? l10n.enterOneOrMoreDay
              : null,
        );
      case ScheduleType.endOfMonth:
        return const SizedBox.shrink();
    }
  }

  Widget _buildDateInput(
    AppLocalizations l10n,
    String label,
    DateTime? date,
    VoidCallback onTap, {
    VoidCallback? onClear,
    String? hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        InputChip(
          label: Text(
            date != null
                ? DateFormat.yMMMd(l10n.localeName).format(date)
                : hintText ?? '',
          ),
          labelStyle: TextStyle(
            color: date != null
                ? null
                : Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.normal,
          ),
          avatar: const Icon(Icons.calendar_today, size: 18),
          onPressed: onTap,
          onDeleted: onClear,
          deleteIcon: onClear != null
              ? const Icon(Icons.clear, size: 18)
              : null,
          showCheckmark: false,
        ),
      ],
    );
  }
}
