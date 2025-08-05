import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:test_app/app/controllers/assets_controller.dart';
import 'package:test_app/app/controllers/expenditure_controller.dart';
import 'package:test_app/app/controllers/settings_controller.dart';
import 'package:test_app/app/helpers/currency_input_formatter.dart';
import 'package:test_app/app/models/saving_goal.dart';
import 'package:test_app/app/views/helpers/glass_card.dart';
import 'package:test_app/app/views/helpers/gradient_background.dart';
import 'package:test_app/app/views/helpers/gradient_title.dart';
import 'package:test_app/app/views/helpers/section_header.dart';
import 'package:test_app/l10n/app_localizations.dart';

class AddEditSavingGoalAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final AppLocalizations l10n;
  final bool isEditing;
  final VoidCallback? onDeletePressed;

  const AddEditSavingGoalAppBar({
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
            text: isEditing ? l10n.editSavingGoal : l10n.addSavingGoal,
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

class AddEditSavingGoalPage extends StatefulWidget {
  final SavingGoal? goal;
  const AddEditSavingGoalPage({super.key, this.goal});

  @override
  State<AddEditSavingGoalPage> createState() => _AddEditSavingGoalPageState();
}

class _AddEditSavingGoalPageState extends State<AddEditSavingGoalPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _notesController;
  late TextEditingController _targetAmountController;
  late TextEditingController _currentAmountController;

  final _contributionAmountController = TextEditingController();
  final _contributionNotesController = TextEditingController();

  late DateTime _startDate;
  DateTime? _endDate;

  bool get isEditing => widget.goal != null;

  @override
  void initState() {
    super.initState();
    final goal = widget.goal;

    final formatter = NumberFormat('#,###');

    _nameController = TextEditingController(text: goal?.name ?? '');
    _notesController = TextEditingController(text: goal?.notes ?? '');
    _targetAmountController = TextEditingController(
      text: goal != null ? formatter.format(goal.targetAmount) : '',
    );
    _currentAmountController = TextEditingController(
      text: goal != null ? formatter.format(goal.currentAmount) : '0',
    );
    _startDate = goal?.startDate ?? DateTime.now();
    _endDate = goal?.endDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    _targetAmountController.dispose();
    _currentAmountController.dispose();
    _contributionAmountController.dispose();
    _contributionNotesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isStart, AppLocalizations l10n) async {
    final initial = isStart ? _startDate : (_endDate ?? DateTime.now());
    final first = isStart ? DateTime(2000) : _startDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: DateTime(2100),
      helpText: l10n.selectDate,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(_startDate)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _addContribution() {
    final l10n = AppLocalizations.of(context)!;

    final sanitizedText = _contributionAmountController.text.replaceAll(
      ',',
      '',
    );
    final amount = double.tryParse(sanitizedText);

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.validNumber)));
      return;
    }

    final assetsController = Provider.of<AssetsController>(
      context,
      listen: false,
    );
    final expenditureController = Provider.of<ExpenditureController>(
      context,
      listen: false,
    );
    final settings = Provider.of<SettingsController>(
      context,
      listen: false,
    ).settings;

    final goalToUpdate = widget.goal!;
    goalToUpdate.currentAmount += amount;
    assetsController.updateSavingGoal(goalToUpdate);

    final transactionName = "${goalToUpdate.name} (${l10n.contribution})";

    expenditureController.addExpenditure(
      settings,
      articleName: transactionName,
      amount: amount,
      date: DateTime.now(),
      mainTagId: 'savings_contribution',
      isIncome: false,
      notes: _contributionNotesController.text.isNotEmpty
          ? _contributionNotesController.text
          : null,
    );

    setState(() {
      final formatter = NumberFormat('#,###');
      _currentAmountController.text = formatter.format(
        goalToUpdate.currentAmount,
      );
      _contributionAmountController.clear();
      _contributionNotesController.clear();
      FocusScope.of(context).unfocus();
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.contributionAdded)));
  }

  void _saveForm() {
    if (!_formKey.currentState!.validate()) return;

    final controller = Provider.of<AssetsController>(context, listen: false);

    final targetAmount =
        double.tryParse(_targetAmountController.text.replaceAll(',', '')) ??
        0.0;
    final currentAmount =
        double.tryParse(_currentAmountController.text.replaceAll(',', '')) ??
        0.0;

    if (isEditing) {
      final goalToUpdate = widget.goal!;
      goalToUpdate.name = _nameController.text;
      goalToUpdate.notes = _notesController.text;
      goalToUpdate.targetAmount = targetAmount;
      goalToUpdate.currentAmount = currentAmount;
      goalToUpdate.startDate = _startDate;
      goalToUpdate.endDate = _endDate;
      controller.updateSavingGoal(goalToUpdate);
    } else {
      controller.addSavingGoal(
        name: _nameController.text,
        notes: _notesController.text,
        targetAmount: targetAmount,
        currentAmount: currentAmount,
        startDate: _startDate,
        endDate: _endDate,
      );
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final addEditAppBar = AddEditSavingGoalAppBar(
      l10n: l10n,
      isEditing: isEditing,
      onDeletePressed: () {
        Provider.of<AssetsController>(
          context,
          listen: false,
        ).deleteSavingGoal(widget.goal!.id);
        Navigator.of(context).pop();
      },
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
                padding: EdgeInsets.fromLTRB(16, totalTopOffset + 16, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildMainInfoCard(l10n),
                    if (isEditing) ...[
                      const SizedBox(height: 24),
                      _buildContributionCard(l10n),
                    ],
                    const SizedBox(height: 24),
                    _buildDetailsCard(l10n),
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
      padding: EdgeInsets.all(12),

      child: Column(
        children: [
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: l10n.goalName,
              filled: true,
              fillColor: Colors.white.withOpacity(0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            validator: (v) => v == null || v.isEmpty ? l10n.nameInput : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _targetAmountController,
            decoration: InputDecoration(
              labelText: l10n.targetAmount,
              prefixText: currencySymbol,
              filled: true,
              fillColor: Colors.white.withOpacity(0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              DecimalCurrencyInputFormatter(locale: l10n.localeName),
            ],
            validator: (v) {
              if (v == null || v.isEmpty) return l10n.validNumber;
              if (double.tryParse(v.replaceAll(',', '')) == null) {
                return l10n.validNumber;
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _currentAmountController,
            decoration: InputDecoration(
              labelText: l10n.currentAmount,
              prefixText: currencySymbol,
              filled: true,
              fillColor: Colors.white.withOpacity(0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              DecimalCurrencyInputFormatter(locale: l10n.localeName),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContributionCard(AppLocalizations l10n) {
    final settings = Provider.of<SettingsController>(
      context,
      listen: false,
    ).settings;
    final currencySymbol = NumberFormat.simpleCurrency(
      name: settings.primaryCurrencyCode,
    ).currencySymbol;

    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          SectionHeader(title: l10n.addContribution),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextFormField(
                  controller: _contributionAmountController,
                  decoration: InputDecoration(
                    labelText: l10n.contributionAmount,
                    prefixText: currencySymbol,
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    DecimalCurrencyInputFormatter(locale: l10n.localeName),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _contributionNotesController,
                  decoration: InputDecoration(
                    labelText: l10n.notesOptional,
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.add_card),
                    label: Text(l10n.saveAsTransaction),
                    onPressed: _addContribution,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
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

  Widget _buildDetailsCard(AppLocalizations l10n) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          SectionHeader(title: l10n.optionalDetails),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.startDate),
                  subtitle: Text(
                    DateFormat.yMMMd(l10n.localeName).format(_startDate),
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () => _pickDate(true, l10n),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.endDateOptional),
                  subtitle: Text(
                    _endDate == null
                        ? l10n.noEndDate
                        : DateFormat.yMMMd(l10n.localeName).format(_endDate!),
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () => _pickDate(false, l10n),
                ),
                if (_endDate != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => setState(() => _endDate = null),
                      child: Text(l10n.clearEndDate),
                    ),
                  ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    labelText: l10n.notesOptional,
                    hintText: l10n.notesHint,
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
