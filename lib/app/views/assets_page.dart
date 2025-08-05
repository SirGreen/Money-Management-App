import 'dart:ui';
import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:test_app/app/controllers/assets_controller.dart';
import 'package:test_app/app/controllers/expenditure_controller.dart';
import 'package:test_app/app/controllers/settings_controller.dart';
import 'package:test_app/app/models/saving_account.dart';
import 'package:test_app/app/models/saving_goal.dart';
import 'package:test_app/app/models/tag.dart';
import 'package:test_app/app/models/budget_status.dart';
import 'package:test_app/app/views/add_edit_budget_page.dart';
import 'package:test_app/app/views/add_edit_saving_account_page.dart';
import 'package:test_app/app/views/add_edit_saving_goal_page.dart';
import 'package:test_app/app/views/helpers/glass_card.dart';
import 'package:test_app/app/views/helpers/gradient_background.dart';
import 'package:test_app/app/views/helpers/gradient_title.dart';
import 'package:test_app/app/views/helpers/shared_axis_page_route.dart';
import 'package:test_app/app/views/helpers/tag_icon.dart';
import 'package:test_app/l10n/app_localizations.dart';

enum BudgetSortOption { overbudget, percent, amount, name }

class AssetsAppBar extends StatelessWidget implements PreferredSizeWidget {
  final AppLocalizations l10n;
  final VoidCallback onRefresh;
  final TabBar? tabBar;
  final bool showSortButton;
  final VoidCallback? onSortPressed;

  const AssetsAppBar({
    super.key,
    required this.l10n,
    required this.onRefresh,
    this.tabBar,
    this.showSortButton = false,
    this.onSortPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: AppBar(
          title: GradientTitle(text: l10n.assets),
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
            if (showSortButton)
              IconButton(
                icon: const Icon(Icons.sort),
                onPressed: onSortPressed,
                tooltip: l10n.sortBy,
              ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: onRefresh,
              tooltip: l10n.refresh,
            ),
          ],
          bottom: tabBar,
        ),
      ),
    );
  }

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (tabBar?.preferredSize.height ?? 0));
}

class AssetsPage extends StatefulWidget {
  final TabController tabController;
  const AssetsPage({super.key, required this.tabController});

  Widget buildFab(BuildContext context, int tabIndex) {
    final l10n = AppLocalizations.of(context)!;
    Widget page;
    String tooltip;

    switch (tabIndex) {
      case 0:
        page = const AddEditBudgetPage();
        tooltip = l10n.addBudget;
        break;
      case 1:
        page = const AddEditSavingAccountPage();
        tooltip = l10n.addSavingAccount;
        break;
      case 2:
      default:
        page = const AddEditSavingGoalPage();
        tooltip = l10n.addSavingGoal;
        break;
    }
    return FloatingActionButton(
      onPressed: () => Navigator.of(context).push(
        SharedAxisPageRoute(
          page: page,
          transitionType: SharedAxisTransitionType.scaled,
        ),
      ),
      tooltip: tooltip,
      child: const Icon(Icons.add),
    );
  }

  @override
  State<AssetsPage> createState() => _AssetsPageState();
}

class _AssetsPageState extends State<AssetsPage> {
  BudgetSortOption _sortOption = BudgetSortOption.overbudget;

  void _showSortOptions() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.warning_amber_rounded),
              title: Text(l10n.sortByOverbudget),
              onTap: () {
                setState(() => _sortOption = BudgetSortOption.overbudget);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.percent),
              title: Text(l10n.sortByPercent),
              onTap: () {
                setState(() => _sortOption = BudgetSortOption.percent);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.paid_outlined),
              title: Text(l10n.sortByAmount),
              onTap: () {
                setState(() => _sortOption = BudgetSortOption.amount);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.sort_by_alpha),
              title: Text(l10n.sortByName),
              onTap: () {
                setState(() => _sortOption = BudgetSortOption.name);
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final assetsController = Provider.of<AssetsController>(context);

    final tabBar = TabBar(
      controller: widget.tabController,
      tabs: [
        Tab(icon: const Icon(Icons.wallet_outlined), text: l10n.budgets),
        Tab(icon: const Icon(Icons.savings_outlined), text: l10n.accounts),
        Tab(icon: const Icon(Icons.flag_outlined), text: l10n.goals),
      ],
      indicatorColor: Theme.of(context).colorScheme.primary,
      labelColor: Theme.of(context).colorScheme.primary,
      unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    final assetsAppBar = AssetsAppBar(
      l10n: l10n,
      onRefresh: () => assetsController.loadAssets(),
      tabBar: tabBar,
      showSortButton: widget.tabController.index == 0,
      onSortPressed: _showSortOptions,
    );
    final double appBarHeight = assetsAppBar.preferredSize.height;
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double totalTopOffset = appBarHeight + statusBarHeight;

    return BackGround(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: assetsAppBar,
        body: TabBarView(
          controller: widget.tabController,
          children: [
            _buildBudgetsList(context, totalTopOffset),
            _buildSavingAccountsList(context, totalTopOffset),
            _buildSavingGoalsList(context, totalTopOffset),
          ],
        ),
      ),
    );
  }

  Widget _buildSavingAccountsList(BuildContext context, double topPadding) {
    final assetsController = Provider.of<AssetsController>(context);
    final l10n = AppLocalizations.of(context)!;
    return RefreshIndicator(
      onRefresh: () => assetsController.loadAssets(),
      edgeOffset: topPadding,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, topPadding + 16, 16, 80),
            sliver: assetsController.savingAccounts.isEmpty
                ? SliverToBoxAdapter(
                    child: _EmptyStateMessage(message: l10n.noSavingAccounts),
                  )
                : SliverList(
                    delegate: SliverChildListDelegate(
                      assetsController.savingAccounts
                          .map((acc) => _SavingAccountCard(account: acc))
                          .toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavingGoalsList(BuildContext context, double topPadding) {
    final assetsController = Provider.of<AssetsController>(context);
    final l10n = AppLocalizations.of(context)!;
    return RefreshIndicator(
      onRefresh: () => assetsController.loadAssets(),
      edgeOffset: topPadding,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, topPadding + 16, 16, 80),
            sliver: assetsController.savingGoals.isEmpty
                ? SliverToBoxAdapter(
                    child: _EmptyStateMessage(message: l10n.noSavingGoals),
                  )
                : SliverList(
                    delegate: SliverChildListDelegate(
                      assetsController.savingGoals
                          .map((goal) => _SavingGoalCard(goal: goal))
                          .toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetsList(BuildContext context, double topPadding) {
    final expenditureController = Provider.of<ExpenditureController>(context);
    final l10n = AppLocalizations.of(context)!;
    final budgetStatuses = expenditureController.tags
        .where((t) => t.budgetAmount != null && t.budgetAmount! > 0)
        .map(
          (tag) =>
              MapEntry(tag, expenditureController.getBudgetStatusForTag(tag)),
        )
        .toList();

    budgetStatuses.sort((a, b) {
      if (a.value.isOverBudget && !b.value.isOverBudget) return -1;
      if (!a.value.isOverBudget && b.value.isOverBudget) return 1;
      switch (_sortOption) {
        case BudgetSortOption.percent:
          return b.value.progress.compareTo(a.value.progress);
        case BudgetSortOption.amount:
          return b.value.spent.compareTo(a.value.budget);
        case BudgetSortOption.name:
          return a.key.name.toLowerCase().compareTo(b.key.name.toLowerCase());
        case BudgetSortOption.overbudget:
          final overA = a.value.spent - a.value.budget;
          final overB = b.value.spent - b.value.budget;
          return overB.compareTo(overA);
      }
    });

    return RefreshIndicator(
      onRefresh: () => expenditureController.loadInitialExpenditures(
        Provider.of<SettingsController>(context, listen: false).settings,
      ),
      edgeOffset: topPadding,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(8, topPadding + 8, 8, 260),
            sliver: budgetStatuses.isEmpty
                ? SliverToBoxAdapter(
                    child: _EmptyStateMessage(message: l10n.noBudgetsSet),
                  )
                : SliverList.builder(
                    itemCount: budgetStatuses.length,
                    itemBuilder: (context, index) {
                      final entry = budgetStatuses[index];
                      return _BudgetCard(
                        tag: entry.key,
                        status: entry.value,
                        onDelete: () => _deleteBudget(context, entry.key),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _deleteBudget(BuildContext context, Tag tag) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteBudget),
        content: Text(l10n.confirmDeleteBudget(tag.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              final controller = Provider.of<ExpenditureController>(
                context,
                listen: false,
              );
              final settings = Provider.of<SettingsController>(
                context,
                listen: false,
              ).settings;
              tag.budgetAmount = null;
              tag.budgetInterval = 'None';
              controller.updateTag(settings, tag);
              Navigator.of(ctx).pop();
            },
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }
}

class _EmptyStateMessage extends StatelessWidget {
  final String message;
  const _EmptyStateMessage({required this.message});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade600),
        ),
      ),
    );
  }
}

class _SavingAccountCard extends StatelessWidget {
  final SavingAccount account;
  const _SavingAccountCard({required this.account});
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = Provider.of<SettingsController>(
      context,
      listen: false,
    ).settings;
    final currencyFormat = NumberFormat.currency(
      locale: l10n.localeName,
      name: settings.primaryCurrencyCode,
      decimalDigits: 2,
    );
    final theme = Theme.of(context);
    double? futureValue;
    if (account.endDate != null) {
      futureValue = account.getEstimatedFutureValue(account.endDate!);
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AddEditSavingAccountPage(account: account),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.secondaryContainer
                      .withOpacity(0.5),
                  child: Icon(
                    Icons.savings_outlined,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(account.name, style: theme.textTheme.titleMedium),
                      if (account.notes != null && account.notes!.isNotEmpty)
                        Text(
                          account.notes!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  currencyFormat.format(account.balance),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.secondary,
                  ),
                ),
              ],
            ),
            if (futureValue != null && futureValue > account.balance)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Column(
                  children: [
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.estimatedValueAt(
                            DateFormat.yMMMd(
                              l10n.localeName,
                            ).format(account.endDate!),
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.green.shade800,
                          ),
                        ),
                        Text(
                          currencyFormat.format(futureValue),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SavingGoalCard extends StatelessWidget {
  final SavingGoal goal;
  const _SavingGoalCard({required this.goal});
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = Provider.of<SettingsController>(
      context,
      listen: false,
    ).settings;
    final currencyFormat = NumberFormat.currency(
      locale: l10n.localeName,
      name: settings.primaryCurrencyCode,
      decimalDigits: 0,
    );
    final theme = Theme.of(context);
    final isCompleted = goal.progress >= 1.0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => AddEditSavingGoalPage(goal: goal)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isCompleted ? Icons.task_alt : Icons.flag_outlined,
                  color: isCompleted ? Colors.green : theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(goal.name, style: theme.textTheme.titleLarge),
                ),
                if (isCompleted)
                  Chip(
                    avatar: const Icon(Icons.check, size: 16),
                    label: Text(l10n.completed),
                    backgroundColor: Colors.green.withOpacity(0.2),
                    labelStyle: const TextStyle(color: Colors.green),
                    side: BorderSide.none,
                  ),
              ],
            ),
            if (goal.notes != null && goal.notes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0, left: 36),
                child: Text(
                  goal.notes!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: goal.progress,
              minHeight: 10,
              borderRadius: BorderRadius.circular(5),
              backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                isCompleted ? Colors.green : theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${currencyFormat.format(goal.currentAmount)} / ${currencyFormat.format(goal.targetAmount)}',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  '${(goal.progress * 100).toStringAsFixed(0)}%',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isCompleted
                        ? Colors.green
                        : theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  final Tag tag;
  final BudgetStatus status;
  final VoidCallback onDelete;
  const _BudgetCard({
    required this.tag,
    required this.status,
    required this.onDelete,
  });

  void _showBudgetAnalysis(BuildContext context, Tag tag) async {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Text(l10n.analyzing),
            ],
          ),
        ),
      ),
    );

    final expenditureController = Provider.of<ExpenditureController>(
      context,
      listen: false,
    );
    final settings = Provider.of<SettingsController>(
      context,
      listen: false,
    ).settings;

    final analysis = await expenditureController.analyzeBudgetForTag(
      tag,
      settings,
    ); 

    Navigator.of(context).pop();

    if (!context.mounted) return;

    if (analysis != null) {
      showDialog(
        context: context,
        builder: (ctx) => _AnalysisResultDialog(analysis: analysis),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.analysisFailed),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = Provider.of<SettingsController>(
      context,
      listen: false,
    ).settings;
    final currencyFormat = NumberFormat.currency(
      locale: l10n.localeName,
      name: settings.primaryCurrencyCode,
      decimalDigits: 0,
    );
    final progressColor = status.isOverBudget
        ? Colors.orange.shade800
        : Theme.of(context).colorScheme.primary;
    final remainingAmount = status.budget - status.spent;
    final remainingColor = remainingAmount >= 0
        ? Colors.green.shade800
        : Colors.red.shade700;
    final transactionLabel = l10n.transactions(status.transactionCount);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: GlassCard(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => AddEditBudgetPage(tag: tag))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: TagIcon(tag: tag, radius: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tag.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        l10n.resetsOn(
                          DateFormat.MMMd(
                            l10n.localeName,
                          ).format(status.resetDate),
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.auto_awesome_outlined,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  onPressed: () => _showBudgetAnalysis(context, tag),
                  tooltip: l10n.budgetAnalysis,
                ),
                if (status.isOverBudget)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange.shade800,
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.grey),
                  onPressed: onDelete,
                  tooltip: l10n.deleteBudget,
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: status.progress,
              minHeight: 12,
              borderRadius: BorderRadius.circular(6),
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              backgroundColor: progressColor.withOpacity(0.2),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${currencyFormat.format(status.spent)} / ${currencyFormat.format(status.budget)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  '${(status.progress * 100).toStringAsFixed(0)}%',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  transactionLabel,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                Text(
                  status.isOverBudget
                      ? l10n.overBudgetBy(
                          currencyFormat.format(remainingAmount.abs()),
                        )
                      : l10n.remaining(currencyFormat.format(remainingAmount)),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: remainingColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalysisResultDialog extends StatelessWidget {
  final Map<String, dynamic> analysis;

  const _AnalysisResultDialog({required this.analysis});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final bool canMeetBudget = analysis['can_meet_budget'] ?? false;
    final double confidence = (analysis['confidence_score'] ?? 0.0) * 100;
    final String summary =
        analysis['analysis_summary'] ?? l10n.noAnalysisSummary;
    final List<String> suggestions = List<String>.from(
      analysis['suggestions'] ?? [],
    );

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.insights, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Text(l10n.budgetAnalysis),
        ],
      ),
      content: SingleChildScrollView(
        child: ListBody(
          children: <Widget>[
            Text(
              canMeetBudget
                  ? l10n.onTrackToMeetBudget
                  : l10n.atRiskOfExceedingBudget,
              style: theme.textTheme.titleMedium?.copyWith(
                color: canMeetBudget
                    ? Colors.green.shade700
                    : Colors.red.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(l10n.confidence(confidence.toStringAsFixed(0))),
            const SizedBox(height: 16),
            Text(summary),
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(l10n.suggestions, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              ...suggestions.map(
                (s) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "• ",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Expanded(child: Text(s)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: Text(l10n.ok),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
