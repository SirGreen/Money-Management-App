import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:test_app/app/controllers/assets_controller.dart';
import 'package:test_app/app/controllers/settings_controller.dart'; 
import 'package:test_app/app/helpers/currency_input_formatter.dart';
import 'package:test_app/app/models/saving_account.dart';
import 'package:test_app/app/views/helpers/glass_card.dart';
import 'package:test_app/app/views/helpers/gradient_background.dart';
import 'package:test_app/app/views/helpers/gradient_title.dart';
import 'package:test_app/app/views/helpers/section_header.dart';
import 'package:test_app/l10n/app_localizations.dart';

class AddEditSavingAccountAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final AppLocalizations l10n;
  final bool isEditing;
  final VoidCallback? onDeletePressed;

  const AddEditSavingAccountAppBar({
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
              text: isEditing ? l10n.editSavingAccount : l10n.addSavingAccount),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.white.withOpacity(0.2),
          shape: RoundedRectangleBorder(
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(32)),
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

class AddEditSavingAccountPage extends StatefulWidget {
  final SavingAccount? account;
  const AddEditSavingAccountPage({super.key, this.account});

  @override
  State<AddEditSavingAccountPage> createState() =>
      _AddEditSavingAccountPageState();
}

class _AddEditSavingAccountPageState extends State<AddEditSavingAccountPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _balanceController;
  late TextEditingController _interestController;
  late TextEditingController _notesController;

  late DateTime _startDate;
  DateTime? _endDate;

  bool get isEditing => widget.account != null;

  @override
  void initState() {
    super.initState();
    final account = widget.account;

    final currencyFormatter = NumberFormat('#,##0.00');

    _nameController = TextEditingController(text: account?.name ?? '');
    _balanceController = TextEditingController(
      text:
          account != null ? currencyFormatter.format(account.balance) : '0.00',
    );
    _interestController = TextEditingController(
      text: account?.annualInterestRate?.toString() ?? '',
    );
    _notesController = TextEditingController(text: account?.notes ?? '');
    _startDate = account?.startDate ?? DateTime.now();
    _endDate = account?.endDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    _interestController.dispose();
    _notesController.dispose();
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

  void _saveForm() {
    if (!_formKey.currentState!.validate()) return;

    final controller = Provider.of<AssetsController>(context, listen: false);

    final balance =
        double.tryParse(_balanceController.text.replaceAll(',', '')) ?? 0.0;
    final interestRate = double.tryParse(_interestController.text);

    if (isEditing) {
      final accountToUpdate = widget.account!;
      accountToUpdate.name = _nameController.text;
      accountToUpdate.balance = balance;
      accountToUpdate.notes = _notesController.text;
      accountToUpdate.startDate = _startDate;
      accountToUpdate.endDate = _endDate;
      accountToUpdate.annualInterestRate = interestRate;
      controller.updateSavingAccount(accountToUpdate);
    } else {
      controller.addSavingAccount(
        name: _nameController.text,
        balance: balance,
        notes: _notesController.text,
        startDate: _startDate,
        endDate: _endDate,
        annualInterestRate: interestRate,
      );
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final addEditAppBar = AddEditSavingAccountAppBar(
      l10n: l10n,
      isEditing: isEditing,
      onDeletePressed: () {
        Provider.of<AssetsController>(context, listen: false)
            .deleteSavingAccount(widget.account!.id);
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
    final settings =
        Provider.of<SettingsController>(context, listen: false).settings;
    final currencySymbol =
        NumberFormat.simpleCurrency(name: settings.primaryCurrencyCode)
            .currencySymbol;

    return GlassCard(
      padding: EdgeInsets.all(12),
      child: Column(
        children: [
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: l10n.accountName,
              filled: true,
              fillColor: Colors.white.withOpacity(0.5),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
            validator: (v) => v == null || v.isEmpty ? l10n.nameInput : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _balanceController,
            decoration: InputDecoration(
              labelText: l10n.currentBalance,
              prefixText: '$currencySymbol ',
              filled: true,
              fillColor: Colors.white.withOpacity(0.5),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              DecimalCurrencyInputFormatter(locale: l10n.localeName)
            ],
            validator: (v) {
              if (v == null || v.isEmpty) return l10n.validNumber;
              if (double.tryParse(v.replaceAll(',', '')) == null)
                return l10n.validNumber;
              return null;
            },
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
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextFormField(
                  controller: _interestController,
                  decoration: InputDecoration(
                    labelText: l10n.annualInterestRate,
                    suffixText: '%',
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.5),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))
                  ],
                ),
                const SizedBox(height: 24),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.openingDate),
                  subtitle:
                      Text(DateFormat.yMMMd(l10n.localeName).format(_startDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () => _pickDate(true, l10n),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.closingDate),
                  subtitle: Text(_endDate == null
                      ? l10n.stillActive
                      : DateFormat.yMMMd(l10n.localeName).format(_endDate!)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () => _pickDate(false, l10n),
                ),
                if (_endDate != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      child: Text(l10n.clearClosingDate,
                          style: const TextStyle(color: Colors.grey)),
                      onPressed: () => setState(() => _endDate = null),
                    ),
                  ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    labelText: l10n.notesOptional,
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.5),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}