import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:test_app/app/controllers/expenditure_controller.dart';
import 'package:test_app/app/controllers/settings_controller.dart';
import 'package:test_app/app/models/scheduled_expenditure.dart';
import 'package:test_app/app/models/settings.dart';
import 'package:test_app/app/views/add_edit_scheduled_page.dart';
import 'package:test_app/app/views/helpers/glass_card.dart';
import 'package:test_app/app/views/helpers/gradient_background.dart';
import 'package:test_app/app/views/helpers/gradient_title.dart';
import 'package:test_app/app/views/helpers/tag_icon.dart';
import 'package:test_app/l10n/app_localizations.dart';

class ManageScheduledAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final AppLocalizations l10n;

  const ManageScheduledAppBar({
    super.key,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: AppBar(
          title: GradientTitle(text: l10n.manageScheduled),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.white.withOpacity(0.2),
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
            side: BorderSide(color: Colors.white.withOpacity(0.3)),
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class ManageScheduledPage extends StatelessWidget {
  const ManageScheduledPage({super.key});

  Future<void> _handleDelete(
    BuildContext context,
    ExpenditureController controller,
    Settings settings,
    ScheduledExpenditure rule,
  ) async {
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

    if (shouldDeleteInstances == null) return;

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

    if (confirmed == true) {
      controller.deleteScheduledExpenditure(
        settings,
        rule.id,
        deleteInstances: shouldDeleteInstances,
      );
    }
  }

  String _getScheduleTypeText(BuildContext context, ScheduledExpenditure rule) {
    final l10n = AppLocalizations.of(context)!;
    switch (rule.scheduleType) {
      case ScheduleType.dayOfMonth:
        return l10n.dayOfMonthLabel(rule.scheduleValue);
      case ScheduleType.endOfMonth:
        return l10n.endOfMonth;
      case ScheduleType.daysBeforeEndOfMonth:
        return l10n.daysBeforeEndOfMonthWithValue(rule.scheduleValue);
      case ScheduleType.fixedInterval:
        return l10n.fixedIntervalWithValue(rule.scheduleValue);
    }
  }

  Widget _buildRuleCard(
    BuildContext context,
    ScheduledExpenditure rule,
    ExpenditureController expenditureController,
    Settings settings,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final mainTag = expenditureController.getTagById(rule.mainTagId);

    final String amountText;
    if (rule.amount != null) {
      final itemCurrencyCode = rule.currencyCode;
      final currencySymbol =
          NumberFormat.simpleCurrency(name: itemCurrencyCode).currencySymbol;
      final formattedAmount = NumberFormat.currency(
              symbol: currencySymbol, decimalDigits: 2)
          .format(rule.amount);
      amountText = '${rule.isIncome ? '+' : '-'}$formattedAmount';
    } else {
      amountText = l10n.noAmountSet;
    }

    return GlassCardContainer(
      padding: EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: rule.isActive ? null : Colors.white.withOpacity(0.2),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) =>
                  AddEditScheduledPage(scheduledExpenditure: rule)),
        );
      },
      child: Opacity(
        opacity: rule.isActive ? 1.0 : 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (mainTag != null) TagIcon(tag: mainTag, radius: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(rule.name,
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Chip(
                        label:
                            Text(rule.isActive ? l10n.active : l10n.inactive),
                        avatar: Icon(
                            rule.isActive ? Icons.check_circle : Icons.cancel,
                            size: 16),
                        backgroundColor: rule.isActive
                            ? Colors.green.shade100
                            : Colors.grey.shade300,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      )
                    ],
                  ),
                ),
                Switch(
                  value: rule.isActive,
                  onChanged: (bool value) {
                    final today = DateTime.now();
                    rule.isActive = value;
                    rule.endDate =
                        value ? null : DateTime(today.year, today.month, today.day);
                    expenditureController.updateScheduledExpenditure(
                        settings, rule);
                  },
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _InfoChip(
                          icon: rule.isIncome
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          text: amountText),
                      _InfoChip(
                          icon: Icons.event_repeat_outlined,
                          text: _getScheduleTypeText(context, rule)),
                      if (rule.endDate != null)
                        _InfoChip(
                            icon: Icons.event_busy,
                            text:
                                '${l10n.end}: ${DateFormat.yMd(l10n.localeName).format(rule.endDate!)}'),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AddEditScheduledPage(
                            scheduledExpenditure: rule,
                          ),
                        ),
                      );
                    } else if (value == 'delete') {
                      _handleDelete(
                          context, expenditureController, settings, rule);
                    }
                  },
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                        value: 'edit', child: Text(l10n.edit)),
                    PopupMenuItem<String>(
                        value: 'delete',
                        child: Text(l10n.delete,
                            style: const TextStyle(color: Colors.red))),
                  ],
                  child: const Icon(Icons.more_vert, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final manageScheduledAppBar = ManageScheduledAppBar(l10n: l10n);

    final double appBarHeight = manageScheduledAppBar.preferredSize.height;
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double totalTopOffset = appBarHeight + statusBarHeight;

    return BackGround(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: manageScheduledAppBar,
        body: Consumer2<ExpenditureController, SettingsController>(
          builder: (context, expenditureController, settingsController, child) {
            final settings = settingsController.settings;
            final scheduledExpenditures =
                expenditureController.scheduledExpenditures;

            if (scheduledExpenditures.isEmpty) {
              return CustomScrollView(
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: EdgeInsets.only(
                          top: totalTopOffset, left: 32, right: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_repeat,
                              size: 80, color: Colors.grey.shade400),
                          const SizedBox(height: 24),
                          Text(l10n.noScheduledRules,
                              style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: 8),
                          Text(
                            l10n.tapToAddFirstRule,
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(color: Colors.grey.shade600),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }
            scheduledExpenditures.sort((a, b) {
              if (a.isActive && !b.isActive) return -1;
              if (!a.isActive && b.isActive) return 1;
              return a.name.compareTo(b.name);
            });

            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding:
                      EdgeInsets.only(top: totalTopOffset + 8, bottom: 80),
                  sliver: SliverList.builder(
                    itemCount: scheduledExpenditures.length,
                    itemBuilder: (context, index) {
                      final rule = scheduledExpenditures[index];
                      return _buildRuleCard(
                          context, rule, expenditureController, settings);
                    },
                  ),
                ),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddEditScheduledPage()));
          },
          tooltip: l10n.addNewRule,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Flexible(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
      ],
    );
  }
}