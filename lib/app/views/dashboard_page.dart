import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:test_app/app/controllers/assets_controller.dart';
import 'package:test_app/app/controllers/expenditure_controller.dart';
import 'package:test_app/app/controllers/settings_controller.dart';
import 'package:test_app/app/models/expenditure.dart';
import 'package:test_app/app/models/saving_goal.dart';
import 'package:test_app/app/models/scheduled_expenditure.dart';
import 'package:test_app/app/models/search_filter.dart';
import 'package:test_app/app/models/tag.dart';
import 'package:test_app/app/views/add_edit_expenditure_page.dart';
import 'package:test_app/app/views/add_edit_saving_account_page.dart';
import 'package:test_app/app/models/saving_account.dart';
import 'package:test_app/app/views/search_results_page.dart';
import 'package:test_app/app/views/add_edit_saving_goal_page.dart';
import 'package:test_app/app/views/camera_scanner_page.dart';
import 'package:test_app/app/views/helpers/glass_card.dart';
import 'package:test_app/app/views/helpers/gradient_background.dart';
import 'package:test_app/app/views/helpers/gradient_title.dart';
import 'package:test_app/app/views/helpers/section_header.dart';
import 'package:test_app/app/views/helpers/tag_icon.dart';
import 'package:test_app/l10n/app_localizations.dart';
import 'package:test_app/app/views/helpers/shared_axis_page_route.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:animations/animations.dart';
// import 'package:flutter/material.dart';

class DashboardAppBar extends StatelessWidget implements PreferredSizeWidget {
  final AppLocalizations l10n;
  const DashboardAppBar({super.key, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: AppBar(
          title: GradientTitle(text: l10n.dashboard),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.white.withOpacity(0.2),
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(32),
            ),
            side: BorderSide(color: Colors.white.withOpacity(0.3)),
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class DashboardPage extends StatelessWidget {
  final VoidCallback onViewAllTransactions;
  final VoidCallback onViewBudgets;
  final VoidCallback onNavigateToSettings;

  const DashboardPage({
    super.key,
    required this.onViewAllTransactions,
    required this.onViewBudgets,
    required this.onNavigateToSettings,
  });

  Widget buildFab(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SpeedDial(
      icon: Icons.add,
      activeIcon: Icons.close,
      spacing: 3,
      tooltip: l10n.addTransaction,
      children: [
        SpeedDialChild(
          child: const Icon(Icons.camera_alt_outlined),
          label: l10n.scanReceipt,
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const CameraScannerPage())),
        ),
        SpeedDialChild(
          child: const Icon(Icons.edit),
          label: l10n.addManually,
          onTap: () => Navigator.of(context).push(
            SharedAxisPageRoute(
              page: const AddEditExpenditurePage(),
              transitionType: SharedAxisTransitionType.scaled,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dashboardAppBar = DashboardAppBar(l10n: l10n);
    final double appBarHeight = dashboardAppBar.preferredSize.height;
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double totalTopOffset = appBarHeight + statusBarHeight;

    return BackGround(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: dashboardAppBar,
        body:
            Consumer3<
              ExpenditureController,
              SettingsController,
              AssetsController
            >(
              builder:
                  (context, expenditureCtrl, settingsCtrl, assetsCtrl, child) {
                    final allTimeBalance = expenditureCtrl
                        .getAllTimeMoneyLeft();
                    final unspecifiedTransactions = expenditureCtrl
                        .getUnspecifiedTransactions();
                    final recentTransactions = expenditureCtrl
                        .getRecentTransactions();
                    final overBudgetTags = expenditureCtrl.getOverBudgetTags();
                    final highSpendingTags = expenditureCtrl
                        .getHighSpendingTags();
                    final endingSavings = assetsCtrl.getEndingSoonSavings();
                    final upcomingScheduled = expenditureCtrl
                        .getUpcomingScheduledTransactions();
                    final bool showBackupReminder = settingsCtrl
                        .shouldShowBackupReminder();

                    return CustomScrollView(
                      slivers: [
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            8,
                            totalTopOffset + 8,
                            8,
                            90,
                          ),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate([
                              _TotalBalanceCard(
                                balance: allTimeBalance,
                                currencyCode:
                                    settingsCtrl.settings.primaryCurrencyCode,
                              ),
                              if (showBackupReminder)
                                _BackupReminderCard(
                                  l10n: l10n,
                                  onTap:
                                      onNavigateToSettings, 
                                ),
                              if (unspecifiedTransactions.isNotEmpty)
                                _AlertCard(
                                  l10n: l10n,
                                  title: l10n.unspecifiedTransactions,
                                  count: unspecifiedTransactions.length,
                                  icon: Icons.help_outline,
                                  onTap: () {
                                    final filter = SearchFilter(
                                      tags: [
                                        expenditureCtrl.getTagById(
                                          ExpenditureController.defaultTagId,
                                        )!,
                                      ],
                                      keyword: 'Default',
                                    );
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => SearchResultsPage(
                                          filter: filter,
                                          findNullAmountTransactions: true,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              _RecentTransactionsCard(
                                l10n: l10n,
                                transactions: recentTransactions,
                                onViewAll: onViewAllTransactions,
                              ),
                              if (overBudgetTags.isNotEmpty)
                                _AlertCard(
                                  l10n: l10n,
                                  title: l10n.overBudget,
                                  count: overBudgetTags.length,
                                  icon: Icons.warning_amber_rounded,
                                  color: Colors.orange,
                                  onTap: onViewBudgets,
                                ),
                              _HighSpendingCard(
                                l10n: l10n,
                                tags: highSpendingTags,
                              ),
                              _EndingSavingsCard(
                                l10n: l10n,
                                savings: endingSavings,
                              ),
                              _UpcomingTransactionsCard(
                                l10n: l10n,
                                scheduled: upcomingScheduled,
                              ),
                            ]),
                          ),
                        ),
                      ],
                    );
                  },
            ),
      ),
    );
  }
}

class _BackupReminderCard extends StatelessWidget {
  final AppLocalizations l10n;
  final VoidCallback onTap;

  const _BackupReminderCard({required this.l10n, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: GlassCard(
        padding: EdgeInsets.all(8),
        onTap: onTap,
        color: Colors.blue.withOpacity(0.2),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          leading: Icon(
            Icons.cloud_upload_outlined,
            color: Colors.blue.shade800,
            size: 32,
          ),
          title: Text(
            l10n.backupReminderTitle,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(l10n.backupReminderSubtitle),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        ),
      ),
    );
  }
}

class _TotalBalanceCard extends StatelessWidget {
  final double balance;
  final String currencyCode;
  const _TotalBalanceCard({required this.balance, required this.currencyCode});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final balanceColor = balance >= 0
        ? Colors.green.shade800
        : Colors.red.shade700;
    final formattedBalance = NumberFormat.currency(
      name: currencyCode,
      decimalDigits: 2,
    ).format(balance);

    return Container(
      margin: const EdgeInsets.all(8),
      child: GlassCard(
        padding: EdgeInsets.all(8),
        child: Column(
          children: [
            Text(
              l10n.allTimeBalance,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              formattedBalance,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: balanceColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final AppLocalizations l10n;
  final String title;
  final int count;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _AlertCard({
    required this.l10n,
    required this.title,
    required this.count,
    required this.icon,
    this.color = Colors.blue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: GlassCard(
        padding: EdgeInsets.all(8),
        onTap: onTap,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          leading: Icon(icon, color: color, size: 32),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(l10n.itemsNeedAttention(count)),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        ),
      ),
    );
  }
}

class _RecentTransactionsCard extends StatelessWidget {
  final AppLocalizations l10n;
  final List<Expenditure> transactions;
  final VoidCallback onViewAll;

  const _RecentTransactionsCard({
    required this.l10n,
    required this.transactions,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            SectionHeader(title: l10n.recentTransactions),
            if (transactions.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(child: Text(l10n.noRecentTransactions)),
              )
            else
              ...transactions.map((exp) {
                final tag = Provider.of<ExpenditureController>(
                  context,
                  listen: false,
                ).getTagById(exp.mainTagId);
                return ListTile(
                  leading: tag != null ? TagIcon(tag: tag) : null,
                  title: Text(exp.articleName),
                  subtitle: Text(
                    DateFormat.yMMMd(l10n.localeName).format(exp.date),
                  ),
                  trailing: Text(
                    NumberFormat.currency(
                      name: exp.currencyCode,
                      decimalDigits: 2,
                    ).format(exp.amount ?? 0.0),
                    style: TextStyle(
                      color: exp.isIncome
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                      fontSize: 14,
                    ),
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AddEditExpenditurePage(expenditure: exp),
                    ),
                  ),
                );
              }),
            const Divider(height: 1, indent: 16, endIndent: 16),
            TextButton(onPressed: onViewAll, child: Text(l10n.viewAll)),
          ],
        ),
      ),
    );
  }
}

class _HighSpendingCard extends StatelessWidget {
  final AppLocalizations l10n;
  final List<Tag> tags;
  const _HighSpendingCard({required this.l10n, required this.tags});

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: GlassCard(
        padding: EdgeInsets.all(8),
        child: Column(
          children: [
            SectionHeader(title: l10n.highSpendingAlert),
            ...tags.map(
              (tag) => ListTile(
                leading: TagIcon(tag: tag),
                title: Text(tag.name),
                subtitle: Text(l10n.spendingHigherThanAverage),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  final now = DateTime.now();
                  final startDate = DateTime(now.year, now.month, 1);
                  final endDate = DateTime(now.year, now.month + 1, 0);
                  final filter = SearchFilter(
                    tags: [tag],
                    startDate: startDate,
                    endDate: endDate,
                    transactionType: TransactionTypeFilter.expense,
                  );
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SearchResultsPage(filter: filter),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EndingSavingsCard extends StatelessWidget {
  final AppLocalizations l10n;
  final List<dynamic> savings;
  const _EndingSavingsCard({required this.l10n, required this.savings});

  @override
  Widget build(BuildContext context) {
    if (savings.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            SectionHeader(title: l10n.goalsEndingSoon),
            ...savings.map((item) {
              final isGoal = item is SavingGoal;
              return InkWell(
                // 1. Wrap ListTile with InkWell
                onTap: () {
                  // 2. Add onTap logic
                  if (isGoal) {
                    // 3. Navigate to AddEditSavingGoalPage
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AddEditSavingGoalPage(goal: item),
                      ),
                    );
                  } else if (item is SavingAccount) {
                    // 3. Navigate to AddEditSavingAccountPage
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AddEditSavingAccountPage(account: item),
                      ),
                    );
                  }
                },
                child: ListTile(
                  leading: Icon(
                    isGoal ? Icons.flag_outlined : Icons.savings_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(item.name),
                  subtitle: Text(
                    '${l10n.endsOn}: ${DateFormat.yMMMd(l10n.localeName).format(item.endDate)}',
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _UpcomingTransactionsCard extends StatelessWidget {
  final AppLocalizations l10n;
  final List<ScheduledExpenditure> scheduled;
  const _UpcomingTransactionsCard({
    required this.l10n,
    required this.scheduled,
  });

  @override
  Widget build(BuildContext context) {
    if (scheduled.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: GlassCard(
        padding: EdgeInsets.all(8),
        child: Column(
          children: [
            SectionHeader(title: l10n.upcoming),
            ...scheduled.map((rule) {
              final amountText = rule.amount != null
                  ? NumberFormat.currency(
                      name: rule.currencyCode,
                      decimalDigits: 2,
                    ).format(rule.amount)
                  : l10n.noAmountSet;
              return ListTile(
                leading: Icon(
                  rule.isIncome ? Icons.arrow_upward : Icons.arrow_downward,
                  color: rule.isIncome ? Colors.green : Colors.red,
                ),
                title: Text(rule.name),
                trailing: Text(amountText),
              );
            }),
          ],
        ),
      ),
    );
  }
}
