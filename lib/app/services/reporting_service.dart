import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:test_app/app/models/budget_status.dart';
import 'package:test_app/app/models/expenditure.dart';
import 'package:test_app/app/models/group_divider.dart';
import 'package:test_app/app/models/report_data.dart';
import 'package:test_app/app/models/settings.dart';
import 'package:test_app/app/models/tag.dart';
import 'package:test_app/app/services/database_service.dart';
import 'package:test_app/app/utils/date_extensions.dart';
import 'package:test_app/l10n/app_localizations.dart';

class ReportingService {
  final DatabaseService _dbService;

  ReportingService(this._dbService);

  BudgetStatus getBudgetStatusForTag(
    Tag tag,
    List<Expenditure> allTransactions,
  ) {
    if (tag.budgetAmount == null || tag.budgetAmount! <= 0) {
      return BudgetStatus(
        spent: 0,
        budget: 0,
        progress: 0,
        isOverBudget: false,
        transactionCount: 0,
        resetDate: DateTime.now(),
      );
    }

    final now = DateTime.now();
    DateTimeRange budgetPeriod;
    DateTime resetDate;

    if (tag.budgetInterval == 'Weekly') {
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      budgetPeriod = DateTimeRange(
        start: DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
        end: DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day + 7),
      );
      resetDate = budgetPeriod.start.add(const Duration(days: 7));
    } else {
      budgetPeriod = DateTimeRange(
        start: DateTime(now.year, now.month, 1),
        end: DateTime(now.year, now.month + 1, 1),
      );
      resetDate = DateTime(now.year, now.month + 1, 1);
    }
    // print('budget period start: ${budgetPeriod.start} ${budgetPeriod.end}');
    final relevantTransactions = allTransactions.where((exp) {
      if (exp.isIncome) return false;
      if (!now.isSameDate(exp.date)) {
        if (exp.date.isBefore(budgetPeriod.start) ||
            exp.date.isAfter(budgetPeriod.end)) {
          return false;
        }
      }
      // print("exp: ${exp.articleName}");
      return exp.mainTagId == tag.id || exp.subTagIds.contains(tag.id);
    }).toList();

    // print("allTrans: ${allTransactions.length}");
    // print("relevantTrans: ${relevantTransactions.length}");
    double totalSpent = 0.0;
    for (final exp in relevantTransactions) {
      totalSpent += exp.amount ?? 0;
    }

    final budget = tag.budgetAmount!;
    final progress = budget > 0 ? (totalSpent / budget) : 0.0;

    return BudgetStatus(
      spent: totalSpent,
      budget: budget,
      progress: progress.clamp(0.0, 1.0),
      isOverBudget: totalSpent > budget,
      transactionCount: relevantTransactions.length,
      resetDate: resetDate,
    );
  }

  double getAllTimeMoneyLeft() {
    final allTransactions = _dbService.getAllExpenditures();
    double transactionNet = 0.0;
    for (final exp in allTransactions) {
      final amount = exp.amount ?? 0;
      transactionNet += exp.isIncome ? amount : -amount;
    }

    final allSavingAccounts = _dbService.getAllSavingAccounts();
    final now = DateTime.now();
    double totalSavingsBalance = 0.0;
    for (final acc in allSavingAccounts) {
      if (acc.isActiveOn(now)) {
        totalSavingsBalance += acc.balance;
      }
    }
    return transactionNet + totalSavingsBalance;
  }

  Future<ReportData> getReportData(
    DateTimeRange dateRange,
    Tag? Function(String id) getTagById,
  ) async {
    final allTransactions = _dbService.getAllExpenditures();
    final inclusiveEndDate = dateRange.end.add(const Duration(days: 1));
    final transactionsInRange = allTransactions.where((exp) {
      return !exp.date.isBefore(dateRange.start) &&
          exp.date.isBefore(inclusiveEndDate);
    }).toList();

    double totalIncome = 0.0;
    double totalExpense = 0.0;
    final Map<String, TagReportData> incomeDataByTagId = {};
    final Map<String, TagReportData> expenseDataByTagId = {};
    final Map<DateTime, double> dailyIncome = {};
    final Map<DateTime, double> dailyExpense = {};

    for (final exp in transactionsInRange) {
      final amount = exp.amount ?? 0;

      if (exp.isIncome) {
        totalIncome += amount;
        incomeDataByTagId.update(
          exp.mainTagId,
          (data) => data
            ..totalAmount += amount
            ..transactionCount += 1,
          ifAbsent: () =>
              TagReportData(totalAmount: amount, transactionCount: 1),
        );
      } else {
        totalExpense += amount;
        expenseDataByTagId.update(
          exp.mainTagId,
          (data) => data
            ..totalAmount += amount
            ..transactionCount += 1,
          ifAbsent: () =>
              TagReportData(totalAmount: amount, transactionCount: 1),
        );
      }

      final day = DateTime(exp.date.year, exp.date.month, exp.date.day);
      if (exp.isIncome) {
        dailyIncome.update(
          day,
          (value) => value + amount,
          ifAbsent: () => amount,
        );
      } else {
        dailyExpense.update(
          day,
          (value) => value + amount,
          ifAbsent: () => amount,
        );
      }
    }

    final Map<Tag, TagReportData> finalIncomeByTag = {};
    incomeDataByTagId.forEach((tagId, data) {
      final tag = getTagById(tagId);
      if (tag != null) finalIncomeByTag[tag] = data;
    });
    final Map<Tag, TagReportData> finalExpenseByTag = {};
    expenseDataByTagId.forEach((tagId, data) {
      final tag = getTagById(tagId);
      if (tag != null) finalExpenseByTag[tag] = data;
    });

    LineChartReportData? lineChartData;
    if (transactionsInRange.isNotEmpty) {
      final incomeSpots =
          dailyIncome.entries
              .map(
                (e) => FlSpot(e.key.millisecondsSinceEpoch.toDouble(), e.value),
              )
              .toList()
            ..sort((a, b) => a.x.compareTo(b.x));

      final expenseSpots =
          dailyExpense.entries
              .map(
                (e) => FlSpot(e.key.millisecondsSinceEpoch.toDouble(), e.value),
              )
              .toList()
            ..sort((a, b) => a.x.compareTo(b.x));

      final allValues = [...dailyIncome.values, ...dailyExpense.values];
      final maxY = allValues.isNotEmpty ? allValues.reduce(max) * 1.2 : 100.0;

      lineChartData = LineChartReportData(
        incomeSpots: incomeSpots,
        expenseSpots: expenseSpots,
        minX: dateRange.start.millisecondsSinceEpoch.toDouble(),
        maxX: dateRange.end.millisecondsSinceEpoch.toDouble(),
        maxY: maxY,
      );
    }

    return ReportData(
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      incomeByTag: finalIncomeByTag,
      expenseByTag: finalExpenseByTag,
      lineChartData: lineChartData,
    );
  }

  List<Object> getGroupedExpenditures(
    List<Expenditure> expenditures,
    Settings settings,
    AppLocalizations? l10n,
  ) {
    if (expenditures.isEmpty) return [];

    switch (settings.dividerType) {
      case DividerType.paydayCycle:
        return _getExpendituresByPaydayCycle(
          settings.paydayStartDay,
          expenditures,
          l10n,
        );
      case DividerType.fixedInterval:
        return _getExpendituresByFixedInterval(
          settings.fixedIntervalDays,
          expenditures,
          l10n,
        );
      case DividerType.monthly:
        return _getExpenditureByMonth(expenditures, l10n);
    }
  }

  List<Object> _getExpendituresByPaydayCycle(
    int startDay,
    List<Expenditure> expenditures,
    AppLocalizations? l10n,
  ) {
    DateTime getCycleStartDate(DateTime date, int day) {
      return date.day >= day
          ? DateTime(date.year, date.month, day)
          : DateTime(date.year, date.month - 1, day);
    }

    final Map<DateTime, double> cycleNetTotals = {};
    for (final exp in expenditures) {
      final amount = exp.amount ?? 0;
      if (amount == 0 && exp.amount != null) continue;
      final signedAmount = exp.isIncome ? amount : -amount;
      final cycleKey = getCycleStartDate(exp.date, startDay);
      cycleNetTotals.update(
        cycleKey,
        (value) => value + signedAmount,
        ifAbsent: () => signedAmount,
      );
    }

    final List<Object> items = [];
    DateTime? lastCycleKey;
    for (final exp in expenditures) {
      final currentCycleKey = getCycleStartDate(exp.date, startDay);
      if (currentCycleKey != lastCycleKey) {
        lastCycleKey = currentCycleKey;
        final cycleEndDate = DateTime(
          currentCycleKey.year,
          currentCycleKey.month + 1,
          startDay - 1,
        );
        final locale = l10n?.localeName ?? 'en';
        final displayTitle =
            "${DateFormat.yMMMd(locale).format(currentCycleKey)} - ${DateFormat.yMMMd(locale).format(cycleEndDate)}";
        final total = cycleNetTotals[currentCycleKey] ?? 0.0;
        items.add(GroupDivider(displayTitle: displayTitle, totalAmount: total));
      }
      items.add(exp);
    }
    return items;
  }

  List<Object> _getExpendituresByDay(
    List<Expenditure> expenditures,
    AppLocalizations? l10n,
  ) {
    final Map<String, double> dailyNetTotals = {};
    for (final exp in expenditures) {
      final amount = exp.amount ?? 0;
      if (amount == 0 && exp.amount != null) continue;
      final signedAmount = exp.isIncome ? amount : -amount;
      final dayKey = DateFormat('yyyy-MM-dd').format(exp.date);
      dailyNetTotals.update(
        dayKey,
        (value) => value + signedAmount,
        ifAbsent: () => signedAmount,
      );
    }

    final List<Object> items = [];
    String? lastDayKey;
    for (final exp in expenditures) {
      final currentDayKey = DateFormat('yyyy-MM-dd').format(exp.date);
      if (currentDayKey != lastDayKey) {
        lastDayKey = currentDayKey;
        final locale = l10n?.localeName ?? 'en';
        final displayTitle = DateFormat.yMMMd(locale).format(exp.date);
        final total = dailyNetTotals[currentDayKey] ?? 0.0;
        items.add(GroupDivider(displayTitle: displayTitle, totalAmount: total));
      }
      items.add(exp);
    }
    return items;
  }

  List<Object> _getExpenditureByMonth(
    List<Expenditure> expenditures,
    AppLocalizations? l10n,
  ) {
    final Map<String, double> monthlyNetTotals = {};
    for (final exp in expenditures) {
      final amount = exp.amount ?? 0;
      if (amount == 0 && exp.amount != null) continue;
      final signedAmount = exp.isIncome ? amount : -amount;
      final monthKey = DateFormat('yyyy-MM').format(exp.date);
      monthlyNetTotals.update(
        monthKey,
        (value) => value + signedAmount,
        ifAbsent: () => signedAmount,
      );
    }

    final List<Object> items = [];
    String? lastMonthKey;
    for (final exp in expenditures) {
      final currentMonthKey = DateFormat('yyyy-MM').format(exp.date);
      if (currentMonthKey != lastMonthKey) {
        lastMonthKey = currentMonthKey;
        final locale = l10n?.localeName ?? 'en';
        final displayTitle = DateFormat.yMMMM(locale).format(exp.date);
        final total = monthlyNetTotals[currentMonthKey] ?? 0.0;
        items.add(GroupDivider(displayTitle: displayTitle, totalAmount: total));
      }
      items.add(exp);
    }
    return items;
  }

  List<Object> _getExpendituresByFixedInterval(
    int intervalDays,
    List<Expenditure> expenditures,
    AppLocalizations? l10n,
  ) {
    if (intervalDays == 1) return _getExpendituresByDay(expenditures, l10n);
    if (intervalDays <= 0) return _getExpenditureByMonth(expenditures, l10n);

    DateTime getGroupStartDate(DateTime date, int interval) {
      final dateUtc = DateTime.utc(date.year, date.month, date.day);
      final epoch = DateTime.utc(1970, 1, 1);
      final daysSinceEpoch = dateUtc.difference(epoch).inDays;
      final groupIndex = daysSinceEpoch ~/ interval;
      final daysFromEpochToGroupStart = groupIndex * interval;
      return epoch.add(Duration(days: daysFromEpochToGroupStart));
    }

    final Map<DateTime, double> intervalNetTotals = {};
    for (final exp in expenditures) {
      final amount = exp.amount ?? 0;
      if (amount == 0 && exp.amount != null) continue;
      final signedAmount = exp.isIncome ? amount : -amount;
      final groupKey = getGroupStartDate(exp.date, intervalDays);
      intervalNetTotals.update(
        groupKey,
        (value) => value + signedAmount,
        ifAbsent: () => signedAmount,
      );
    }

    final List<Object> items = [];
    DateTime? lastGroupKey;
    for (final exp in expenditures) {
      final currentGroupKey = getGroupStartDate(exp.date, intervalDays);
      if (currentGroupKey != lastGroupKey) {
        lastGroupKey = currentGroupKey;
        final intervalEnd = currentGroupKey.add(
          Duration(days: intervalDays - 1),
        );
        final locale = l10n?.localeName ?? 'en';
        final displayTitle =
            "${DateFormat.yMMMd(locale).format(currentGroupKey)} - ${DateFormat.yMMMd(locale).format(intervalEnd)}";
        final total = intervalNetTotals[currentGroupKey] ?? 0.0;
        items.add(GroupDivider(displayTitle: displayTitle, totalAmount: total));
      }
      items.add(exp);
    }
    return items;
  }

  List<Tag> getHighSpendingTags(
    List<Expenditure> allTransactions,
    Tag? Function(String id) getTagById,
  ) {
    final now = DateTime.now();
    final Map<String, List<double>> monthlySpendingByTag = {};

    final recentTransactions = allTransactions.where(
      (exp) =>
          !exp.isIncome &&
          exp.date.isAfter(now.subtract(const Duration(days: 90))),
    );

    for (var exp in recentTransactions) {
      final tagId = exp.mainTagId;
      monthlySpendingByTag.putIfAbsent(tagId, () => []);
      monthlySpendingByTag[tagId]!.add(exp.amount ?? 0);
    }

    final List<Tag> highSpendingTags = [];
    final currentMonthKey = DateFormat('yyyy-MM').format(now);

    monthlySpendingByTag.forEach((tagId, spendingList) {
      if (spendingList.length < 2) return;

      final averageSpending =
          spendingList.reduce((a, b) => a + b) / spendingList.length;

      final currentMonthSpending = recentTransactions
          .where(
            (exp) =>
                exp.mainTagId == tagId &&
                DateFormat('yyyy-MM').format(exp.date) == currentMonthKey,
          )
          .fold(0.0, (sum, exp) => sum + (exp.amount ?? 0));

      if (currentMonthSpending > (averageSpending * 1.15)) {
        final tag = getTagById(tagId);
        if (tag != null) {
          highSpendingTags.add(tag);
        }
      }
    });

    return highSpendingTags;
  }

  List<Tag> getOverBudgetTags(
    List<Tag> allTags,
    List<Expenditure> allTransactions,
  ) {
    final overBudget = <Tag>[];
    final budgetedTags = allTags.where(
      (t) => t.budgetAmount != null && t.budgetAmount! > 0,
    );

    for (final tag in budgetedTags) {
      final status = getBudgetStatusForTag(tag, allTransactions);
      if (status.isOverBudget) {
        overBudget.add(tag);
      }
    }
    return overBudget;
  }
}
