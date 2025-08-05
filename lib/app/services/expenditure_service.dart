import 'package:test_app/app/models/expenditure.dart';
import 'package:test_app/app/models/settings.dart';
import 'package:test_app/app/models/search_filter.dart';
import 'package:test_app/app/models/pagination_result.dart';
import 'package:test_app/app/models/tag.dart';
import 'package:test_app/app/services/database_service.dart';
import 'package:test_app/app/utils/date_extensions.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ExpenditureService {
  final DatabaseService _dbService;
  final Uuid _uuid = Uuid();
  static const String defaultArticleName = 'Default - ';

  ExpenditureService(this._dbService);

  Future<void> deleteAllData() async {
    await _dbService.deleteAllData();
  }

  List<Expenditure> getTransactionsForTagInRange(Tag tag, DateTimeRange range) {
    final allTransactions = _dbService.getAllExpenditures();
    final inclusiveEndDate = range.end.add(const Duration(days: 1));
    return allTransactions.where((exp) {
      final isDateInRange =
          !exp.date.isBefore(range.start) &&
          exp.date.isBefore(inclusiveEndDate);
      if (!isDateInRange) {
        return false;
      }
      return exp.mainTagId == tag.id || exp.subTagIds.contains(tag.id);
    }).toList();
  }

  Future<PaginationResult> getExpendituresWithPagination({
    required Settings settings,
    required int currentCount,
    Expenditure? lastLoadedExpenditure,
  }) async {
    final allIds = _dbService.getAllExpenditureIdsSortedByDate();

    if (allIds.isEmpty || currentCount >= allIds.length) {
      return PaginationResult(expenditures: [], hasMore: false);
    }
    List<String> idsToLoad = [];
    if (currentCount == 0) {
      String? firstGroupKey;
      for (int i = 0; i < allIds.length; i++) {
        final id = allIds[i];
        final exp = _dbService.getExpenditureById(id);
        if (exp == null) continue;
        firstGroupKey ??= _getGroupKeyForExpenditure(exp, settings);

        idsToLoad.add(id);

        if (idsToLoad.length >= settings.paginationLimit) {
          final currentGroupKey = _getGroupKeyForExpenditure(exp, settings);
          if (currentGroupKey != firstGroupKey) {
            break;
          }
        }
      }
    }
    else {
      final lastGroupKey = _getGroupKeyForExpenditure(
        lastLoadedExpenditure!,
        settings,
      );
      String? nextGroupKey;
      for (int i = currentCount; i < allIds.length; i++) {
        final id = allIds[i];
        final expenditure = _dbService.getExpenditureById(id);
        if (expenditure == null) continue;

        final currentItemKey = _getGroupKeyForExpenditure(
          expenditure,
          settings,
        );

        if (nextGroupKey == null) {
          if (currentItemKey != lastGroupKey) {
            nextGroupKey = currentItemKey;
            idsToLoad.add(id);
          }
        } else {
          if (currentItemKey == nextGroupKey) {
            idsToLoad.add(id);
          } else {
            break;
          }
        }
      }
    }

    if (idsToLoad.isEmpty) {
      return PaginationResult(expenditures: [], hasMore: false);
    }

    final newExpenditures = _dbService.getExpendituresByIds(idsToLoad);
    final hasMore = (currentCount + newExpenditures.length) < allIds.length;

    return PaginationResult(expenditures: newExpenditures, hasMore: hasMore);
  }

  String _getGroupKeyForExpenditure(Expenditure exp, Settings settings) {
    switch (settings.dividerType) {
      case DividerType.paydayCycle:
        final startDay = settings.paydayStartDay;
        final date = exp.date;
        final cycleStartDate = date.day >= startDay
            ? DateTime(date.year, date.month, startDay)
            : DateTime(date.year, date.month - 1, startDay);
        return DateFormat('yyyy-MM-dd').format(cycleStartDate);

      case DividerType.fixedInterval:
        final intervalDays = settings.fixedIntervalDays;
        final intervalMillis = intervalDays * 24 * 60 * 60 * 1000;
        final groupId = exp.date.millisecondsSinceEpoch ~/ intervalMillis;
        return groupId.toString();

      case DividerType.monthly:
        return DateFormat('yyyy-MM').format(exp.date);
    }
  }

  List<Expenditure> getFilteredExpenditures(
    SearchFilter filter, {
    required bool findNullAmountTransactions,
  }) {
    List<Expenditure> allExpenditures = _dbService.getAllExpenditures();
    List<Expenditure> results = [];

    if (findNullAmountTransactions) {
      results = allExpenditures.where((exp) => exp.amount == null).toList();
      return results;
    }

    results = allExpenditures;

    if (filter.keyword != null && filter.keyword!.isNotEmpty) {
      results = results
          .where(
            (exp) => exp.articleName.toLowerCase().contains(
              filter.keyword!.toLowerCase(),
            ),
          )
          .toList();
    }

    if (filter.startDate != null) {
      results = results
          .where((exp) => !exp.date.isBefore(filter.startDate!))
          .toList();
    }

    if (filter.endDate != null) {
      final inclusiveEndDate = filter.endDate!.add(const Duration(days: 1));
      results = results
          .where((exp) => exp.date.isBefore(inclusiveEndDate))
          .toList();
    }

    if (filter.transactionType == TransactionTypeFilter.income) {
      results = results.where((exp) => exp.isIncome).toList();
    } else if (filter.transactionType == TransactionTypeFilter.expense) {
      results = results.where((exp) => !exp.isIncome).toList();
    }

    if (filter.minAmount != null) {
      results = results
          .where((exp) => (exp.amount ?? 0) >= filter.minAmount!)
          .toList();
    }

    if (filter.maxAmount != null) {
      results = results
          .where((exp) => (exp.amount ?? 0) <= filter.maxAmount!)
          .toList();
    }

    if (filter.tags != null && filter.tags!.isNotEmpty) {
      final tagIds = filter.tags!.map((tag) => tag.id).toSet();
      results = results.where((exp) {
        if (tagIds.contains(exp.mainTagId)) return true;
        return exp.subTagIds.any((subTagId) => tagIds.contains(subTagId));
      }).toList();
    }

    return results;
  }

  Future<void> addExpenditure({
    required Settings settings,
    required String articleName,
    double? amount,
    required DateTime date,
    required String mainTagId,
    required bool isIncome,
    List<String> subTagIds = const [],
    String? receiptImagePath,
    String? scheduledExpenditureId,
    String? notes,
  }) async {
    final newExpenditure = Expenditure(
      id: _uuid.v4(),
      articleName: articleName,
      amount: amount,
      date: date,
      mainTagId: mainTagId,
      isIncome: isIncome,
      subTagIds: subTagIds,
      receiptImagePath: receiptImagePath,
      scheduledExpenditureId: scheduledExpenditureId,
      currencyCode: settings.primaryCurrencyCode,
      notes: notes,
    );
    await _dbService.saveExpenditure(newExpenditure);
  }

  Future<void> updateExpenditure(Expenditure expenditure) async {
    expenditure.updatedAt = DateTime.now();
    await _dbService.saveExpenditure(expenditure);
  }

  Future<void> deleteExpenditure(String id) async {
    await _dbService.deleteExpenditure(id);
  }

  Future<void> resetAllData() async {
    await _dbService.deleteAllData();
  }

  int getIncompleteTransactionsTodayCount() {
    final now = DateTime.now();
    final allExpenditures = _dbService.getAllExpenditures();

    final incompleteToday = allExpenditures.where((exp) {
      if (!exp.date.isSameDate(now)) {
        return false;
      }

      final bool hasNoAmount = exp.amount == null;
      final bool hasDefaultName = exp.articleName.contains(defaultArticleName);

      return hasNoAmount || hasDefaultName;
    }).toList();

    return incompleteToday.length;
  }

  List<Expenditure> getUnspecifiedTransactions() {
    return _dbService
        .getAllExpenditures()
        .where(
          (exp) =>
              (exp.articleName.contains('Default')) || (exp.amount == null),
        )
        .toList();
  }
}
