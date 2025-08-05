import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:test_app/app/controllers/expenditure_controller.dart';
import 'package:test_app/app/controllers/settings_controller.dart';
import 'package:test_app/app/helpers/currency_input_formatter.dart';
import 'package:test_app/app/models/tag.dart';
import 'package:test_app/app/views/add_edit_expenditure_page.dart';
import 'package:test_app/app/views/helpers/glass_card.dart';
import 'package:test_app/app/views/helpers/gradient_background.dart';
import 'package:test_app/app/views/helpers/gradient_title.dart';
import 'package:test_app/app/views/helpers/tag_icon.dart';
import 'package:test_app/l10n/app_localizations.dart';

class AddEditBudgetAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final AppLocalizations l10n;
  final bool isEditing;
  final TabBar? tabBar;

  const AddEditBudgetAppBar({
    super.key,
    required this.l10n,
    required this.isEditing,
    this.tabBar,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: AppBar(
          title: GradientTitle(
            text: isEditing ? l10n.editBudget : l10n.addBudget,
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
          bottom: tabBar,
        ),
      ),
    );
  }

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (tabBar?.preferredSize.height ?? 0));
}

class AddEditBudgetPage extends StatefulWidget {
  final Tag? tag;
  const AddEditBudgetPage({super.key, this.tag});

  @override
  State<AddEditBudgetPage> createState() => _AddEditBudgetPageState();
}

class _AddEditBudgetPageState extends State<AddEditBudgetPage> {
  final _formKey = GlobalKey<FormState>();

  Tag? _selectedTag;
  late TextEditingController _budgetAmountController;
  String _budgetInterval = 'Monthly';

  bool get isEditing => widget.tag != null;

  @override
  void initState() {
    super.initState();
    _selectedTag = widget.tag;
    _budgetAmountController = TextEditingController(
      text: widget.tag?.budgetAmount?.toStringAsFixed(0) ?? '',
    );
    _budgetInterval = widget.tag?.budgetInterval ?? 'Monthly';
  }

  @override
  void dispose() {
    _budgetAmountController.dispose();
    super.dispose();
  }

  void _saveBudget() {
    if (!_formKey.currentState!.validate() || _selectedTag == null) {
      if (_selectedTag == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.selectTag)),
        );
      }
      return;
    }

    final controller = Provider.of<ExpenditureController>(
      context,
      listen: false,
    );
    final settings = Provider.of<SettingsController>(
      context,
      listen: false,
    ).settings;

    final tagToUpdate = _selectedTag!;
    tagToUpdate.budgetAmount = double.tryParse(
      _budgetAmountController.text.replaceAll(',', ''),
    );
    tagToUpdate.budgetInterval = _budgetInterval;

    controller.updateTag(settings, tagToUpdate);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BackGround(
      child: isEditing
          ? _buildEditingView(context, l10n)
          : _buildAddingView(context, l10n),
    );
  }

  Widget _buildAddingView(BuildContext context, AppLocalizations l10n) {
    final appBar = AddEditBudgetAppBar(l10n: l10n, isEditing: isEditing);
    final double appBarHeight = appBar.preferredSize.height;
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double totalTopOffset = appBarHeight + statusBarHeight;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: appBar,
      body: _buildBudgetForm(context, l10n, totalTopOffset),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveBudget,
        label: Text(l10n.saveBudget),
        icon: const Icon(Icons.check),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildEditingView(BuildContext context, AppLocalizations l10n) {
    final tabBar = TabBar(
      tabs: [
        Tab(icon: const Icon(Icons.settings_outlined), text: l10n.settings),
        Tab(icon: const Icon(Icons.list_alt), text: l10n.trans),
      ],
      indicatorColor: Theme.of(context).colorScheme.primary,
      labelColor: Theme.of(context).colorScheme.primary,
      unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    final appBar = AddEditBudgetAppBar(
      l10n: l10n,
      isEditing: isEditing,
      tabBar: tabBar,
    );
    final double appBarHeight = appBar.preferredSize.height;
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double totalTopOffset = appBarHeight + statusBarHeight;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: appBar,
        body: TabBarView(
          children: [
            _buildBudgetForm(context, l10n, totalTopOffset),
            _buildTransactionsList(context, l10n, totalTopOffset),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _saveBudget,
          label: Text(l10n.update),
          icon: const Icon(Icons.check),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  Widget _buildBudgetForm(
    BuildContext context,
    AppLocalizations l10n,
    double topPadding,
  ) {
    final settings = Provider.of<SettingsController>(
      context,
      listen: false,
    ).settings;
    final currencySymbol = NumberFormat.simpleCurrency(
      name: settings.primaryCurrencyCode,
    ).currencySymbol;

    return Form(
      key: _formKey,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, topPadding + 16, 16, 100),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (isEditing)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: TagIcon(tag: _selectedTag!),
                    title: Text(
                      _selectedTag!.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    subtitle: Text(l10n.editingBudgetForThisTag),
                  )
                else
                  Consumer<ExpenditureController>(
                    builder: (context, controller, child) {
                      List<Tag> availableTags = controller.tags
                          .where(
                            (t) =>
                                t.budgetAmount == null || t.budgetAmount! <= 0,
                          )
                          .toList();

                      final availableTagIds = availableTags
                          .map((t) => t.id)
                          .toSet();

                      if (_selectedTag != null &&
                          !availableTagIds.contains(_selectedTag!.id)) {
                        availableTags.insert(0, _selectedTag!);
                      }

                      return DropdownButtonFormField<Tag>(
                        value: _selectedTag,
                        decoration: InputDecoration(
                          labelText: l10n.selectTagForBudget,
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: availableTags
                            .map(
                              (tag) => DropdownMenuItem(
                                value: tag,
                                child: Row(
                                  children: [
                                    TagIcon(tag: tag, radius: 12),
                                    const SizedBox(width: 12),
                                    Text(tag.name),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (tag) => setState(() => _selectedTag = tag),
                        validator: (v) => v == null ? l10n.selectTag : null,
                      );
                    },
                  ),

                const Divider(height: 32),

                TextFormField(
                  controller: _budgetAmountController,
                  decoration: InputDecoration(
                    labelText: l10n.budgetAmount,
                    prefixText: currencySymbol,
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    DecimalCurrencyInputFormatter(locale: l10n.localeName),
                  ],
                  validator: (v) =>
                      v == null ||
                          v.isEmpty ||
                          double.tryParse(v.replaceAll(',', '')) == null
                      ? l10n.validNumber
                      : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _budgetInterval,
                  decoration: InputDecoration(
                    labelText: l10n.budgetPeriod,
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: ['Monthly', 'Weekly'].map((period) {
                    return DropdownMenuItem(
                      value: period,
                      child: Text(l10n.budgetPeriodName(period)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _budgetInterval = value);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList(
    BuildContext context,
    AppLocalizations l10n,
    double topPadding,
  ) {
    final expenditureController = Provider.of<ExpenditureController>(
      context,
      listen: false,
    );
    final settingsController = Provider.of<SettingsController>(
      context,
      listen: false,
    );
    final currencyCode = settingsController.settings.primaryCurrencyCode;

    final now = DateTime.now();
    DateTimeRange budgetPeriod;
    if (_budgetInterval == 'Weekly') {
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      budgetPeriod = DateTimeRange(
        start: DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
        end: now,
      );
    } else {
      budgetPeriod = DateTimeRange(
        start: DateTime(now.year, now.month, 1),
        end: now,
      );
    }

    final transactions = expenditureController.getTransactionsForTagInRange(
      _selectedTag!,
      budgetPeriod,
    );

    if (transactions.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(top: topPadding),
        child: Center(child: Text(l10n.noTransactionsInPeriod)),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(8, topPadding + 8, 8, 80),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final expenditure = transactions[index];
        final amountString = expenditure.amount != null
            ? NumberFormat.currency(
                locale: l10n.localeName,
                name: currencyCode,
                decimalDigits: 0,
              ).format(expenditure.amount)
            : l10n.noAmountSet;

        return GlassCardContainer(
          margin: const EdgeInsets.symmetric(vertical: 4.0),
          padding: EdgeInsets.zero,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AddEditExpenditurePage(expenditure: expenditure),
            ),
          ),
          child: ListTile(
            leading: TagIcon(tag: _selectedTag!),
            title: Text(expenditure.articleName),
            subtitle: Text(
              DateFormat.yMMMd(l10n.localeName).format(expenditure.date),
            ),
            trailing: Text(
              amountString,
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }
}
