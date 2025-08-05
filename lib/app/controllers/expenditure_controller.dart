import 'package:flutter/material.dart';
import 'package:test_app/app/models/budget_status.dart';
import 'package:test_app/app/models/expenditure.dart';
import 'package:test_app/app/models/report_data.dart';
import 'package:test_app/app/models/tag.dart';
import 'package:test_app/app/models/settings.dart';
import 'package:test_app/app/models/scheduled_expenditure.dart';
import 'package:test_app/app/models/search_filter.dart';
import 'package:test_app/app/services/currency_api_service.dart';
import 'package:test_app/app/services/currency_service.dart';
import 'package:test_app/app/services/database_service.dart';
import 'package:test_app/app/services/expenditure_service.dart';
import 'package:test_app/app/services/llm_service.dart';
import 'package:test_app/app/services/reporting_service.dart';
import 'package:test_app/app/services/scheduled_expenditure_service.dart';
import 'package:test_app/app/services/tag_service.dart';
import 'package:test_app/l10n/app_localizations.dart';
import 'package:collection/collection.dart';

class ExpenditureController with ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  late final ExpenditureService _expenditureService;
  late final TagService _tagService;
  late final ReportingService _reportingService;
  late final ScheduledExpenditureService _scheduledExpenditureService;
  late final CurrencyService _currencyService;
  final LLMService _llmService = LLMService();

  List<Expenditure> _expenditures = [];
  List<Tag> _tags = [];
  List<ScheduledExpenditure> _scheduledExpenditures = [];
  AppLocalizations? _l10n;
  bool _isLoading = false;
  bool _hasMoreExpenditures = true;

  List<Expenditure> get expenditures => _expenditures;
  List<Tag> get tags => _tags;
  List<ScheduledExpenditure> get scheduledExpenditures =>
      _scheduledExpenditures;
  bool get isLoading => _isLoading;
  bool get hasMoreExpenditures => _hasMoreExpenditures;
  static String get defaultTagId => TagService.defaultTagId;

  ExpenditureController() {
    _expenditureService = ExpenditureService(_dbService);
    _tagService = TagService(_dbService);
    _reportingService = ReportingService(_dbService);
    _scheduledExpenditureService = ScheduledExpenditureService(_dbService);
    final apiService = CurrencyAPIService();
    _currencyService = CurrencyService(_dbService, apiService);
  }

  Future<void> initialize(AppLocalizations l10n, Settings settings) async {
    _l10n = l10n;
    await _loadAllNonExpenditureData();
    await _processAndReloadScheduledExpenditures(settings);
    await loadInitialExpenditures(settings);
  }

  Future<void> _loadAllNonExpenditureData() async {
    _tags = _tagService.getAllTags();
    _scheduledExpenditures = _scheduledExpenditureService
        .getAllScheduledExpenditures();
    if (_tags.isEmpty && _l10n != null) {
      await _tagService.createDefaultTags(_l10n!);
      _tags = _tagService.getAllTags();
    }
  }

  Future<void> _processAndReloadScheduledExpenditures(Settings settings) async {
    final bool createdAny = await _scheduledExpenditureService
        .processScheduledExpenditures();
    // print("today created more scheduled expenditure: $createdAny");
    if (createdAny) {
      await loadInitialExpenditures(settings);
    }
  }

  Future<void> loadInitialExpenditures(Settings settings) async {
    if (_isLoading) return;
    _setLoading(true);
    _expenditures = [];
    final result = await _expenditureService.getExpendituresWithPagination(
      settings: settings,
      currentCount: 0,
    );
    _expenditures = result.expenditures;
    _hasMoreExpenditures = result.hasMore;
    _setLoading(false);
  }

  Future<void> loadMoreExpenditures(Settings settings) async {
    if (_isLoading || !_hasMoreExpenditures) return;
    _setLoading(true);
    final result = await _expenditureService.getExpendituresWithPagination(
      settings: settings,
      currentCount: _expenditures.length,
      lastLoadedExpenditure: _expenditures.last,
    );
    if (result.expenditures.isNotEmpty) {
      _expenditures.addAll(result.expenditures);
    }
    _hasMoreExpenditures = result.hasMore;
    _setLoading(false);
  }

  Future<void> resetAllData(Settings settings) async {
    await _expenditureService.deleteAllData();
    await initialize(_l10n!, settings);
  }

  List<Expenditure> getTransactionsForTagInRange(Tag tag, DateTimeRange range) {
    return _expenditureService.getTransactionsForTagInRange(tag, range);
  }

  double getAllTimeMoneyLeft() {
    return _reportingService.getAllTimeMoneyLeft();
  }

  Future<void> addExpenditure(
    Settings settings, {
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
    await _expenditureService.addExpenditure(
      settings: settings,
      articleName: articleName,
      amount: amount,
      date: date,
      mainTagId: mainTagId,
      isIncome: isIncome,
      subTagIds: subTagIds,
      receiptImagePath: receiptImagePath,
      scheduledExpenditureId: scheduledExpenditureId,
      notes: notes,
    );

    await loadInitialExpenditures(settings);
  }

  Future<void> updateExpenditure(
    Settings settings,
    Expenditure expenditure,
  ) async {
    await _expenditureService.updateExpenditure(expenditure);
    await loadInitialExpenditures(settings);
  }

  Future<void> deleteExpenditure(Settings settings, String id) async {
    await _expenditureService.deleteExpenditure(id);
    await loadInitialExpenditures(settings);
  }

  Tag? getTagById(String id) {
    return _tags.firstWhereOrNull((tag) => tag.id == id);
  }

  Future<void> addTag({
    String? id,
    required String name,
    required int colorValue,
    String? iconName,
    String? imagePath,
  }) async {
    await _tagService.addTag(
      id: id,
      name: name,
      colorValue: colorValue,
      iconName: iconName,
      imagePath: imagePath,
    );
    await _loadAllNonExpenditureData();
    notifyListeners();
  }

  Future<void> updateTag(Settings settings, Tag tag) async {
    await _tagService.updateTag(tag);
    await _loadAllNonExpenditureData();
    notifyListeners();
  }

  Future<void> deleteTag(Settings settings, String tagId) async {
    final success = await _tagService.deleteTag(tagId);
    if (success) {
      await initialize(_l10n!, settings);
    }
  }

  Future<List<Object>> recommendTags(String articleName) async {
    if (articleName.isEmpty || articleName.length < 3) {
      return [];
    }
    final existingTagNames = _tags.map((t) => t.name).toList();
    final recommendationJson = await _llmService.recommendTags(
      articleName,
      existingTagNames,
    );
    if (recommendationJson == null) {
      return [];
    }
    final List<Object> recommendations = [];
    if (recommendationJson['existing_tags'] is List) {
      final List<String> suggestedNames = List<String>.from(
        recommendationJson['existing_tags'],
      );
      for (var name in suggestedNames) {
        try {
          final tag = _tags.firstWhere(
            (t) => t.name.toLowerCase() == name.toLowerCase(),
          );

          if (!recommendations.any(
            (item) => item is Tag && item.id == tag.id,
          )) {
            recommendations.add(tag);
          }
        } catch (e) {
          print("Could not find recommended existing tag: $name. Error: $e");
        }
      }
    }
    if (recommendationJson['new_tag_suggestion'] is String) {
      final String newTagName = recommendationJson['new_tag_suggestion'];
      if (newTagName.isNotEmpty) {
        final alreadyExists = _tags.any(
          (t) => t.name.toLowerCase() == newTagName.toLowerCase(),
        );
        final alreadyRecommended = recommendations.any(
          (item) =>
              item is String && item.toLowerCase() == newTagName.toLowerCase(),
        );
        if (!alreadyExists && !alreadyRecommended) {
          recommendations.add(newTagName);
        }
      }
    }
    return recommendations;
  }

  Future<void> addScheduledExpenditure(
    Settings settings,
    ScheduledExpenditure scheduled,
  ) async {
    await _scheduledExpenditureService.addScheduledExpenditure(scheduled);
    await initialize(_l10n!, settings);
  }

  Future<void> updateScheduledExpenditure(
    Settings settings,
    ScheduledExpenditure scheduled, {
    bool updatePastAmounts = false,
  }) async {
    await _scheduledExpenditureService.updateScheduledExpenditure(
      scheduled,
      updatePastAmounts: updatePastAmounts,
    );
    await initialize(_l10n!, settings);
  }

  int getIncompleteTransactionsTodayCount() {
    return _expenditureService.getIncompleteTransactionsTodayCount();
  }

  Future<void> deleteScheduledExpenditure(
    Settings settings,
    String id, {
    required bool deleteInstances,
  }) async {
    await _scheduledExpenditureService.deleteScheduledExpenditure(
      id,
      deleteInstances: deleteInstances,
    );
    await initialize(_l10n!, settings);
  }

  BudgetStatus getBudgetStatusForTag(Tag tag) {
    return _reportingService.getBudgetStatusForTag(tag, _dbService.getAllExpenditures());
  }

  Future<ReportData> getReportData(DateTimeRange dateRange) async {
    return _reportingService.getReportData(dateRange, getTagById);
  }

  List<Object> getGroupedExpenditures(
    Settings settings, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    List<Expenditure> listToGroup = _expenditures;
    if (startDate != null) {
      listToGroup = listToGroup
          .where((exp) => !exp.date.isBefore(startDate))
          .toList();
    }
    if (endDate != null) {
      final inclusiveEndDate = endDate.add(const Duration(days: 1));
      listToGroup = listToGroup
          .where((exp) => exp.date.isBefore(inclusiveEndDate))
          .toList();
    }

    return _reportingService.getGroupedExpenditures(
      listToGroup,
      settings,
      _l10n,
    );
  }

  List<Expenditure> getFilteredExpenditures(
    SearchFilter filter,
    bool findNullAmountTransactions,
  ) {
    return _expenditureService.getFilteredExpenditures(
      filter,
      findNullAmountTransactions: findNullAmountTransactions,
    );
  }

  List<Expenditure> getUnspecifiedTransactions() {
    return _expenditureService.getUnspecifiedTransactions();
  }

  List<Expenditure> getRecentTransactions() {
    final sorted = List<Expenditure>.from(_expenditures)
      ..sort((a, b) => b.date.compareTo(a.date));
    return sorted.take(3).toList();
  }

  List<Tag> getOverBudgetTags() {
    return _reportingService.getOverBudgetTags(_tags, _expenditures);
  }

  List<ScheduledExpenditure> getUpcomingScheduledTransactions() {
    return _scheduledExpenditureService.getUpcomingScheduledTransactions(
      _scheduledExpenditures,
    );
  }

  List<Tag> getHighSpendingTags() {
    return _reportingService.getHighSpendingTags(_expenditures, getTagById);
  }

  Future<void> convertAllExpenditures(
    double rate,
    String newCurrencyCode,
    Settings settings,
  ) async {
    await _currencyService.convertAllData(rate, newCurrencyCode);
    await initialize(_l10n!, settings);
  }

  Future<double?> getBestExchangeRate(String from, String to) async {
    return await _currencyService.getBestExchangeRate(from, to);
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  DateTimeRange _getCurrentBudgetPeriod(String interval) {
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate;

    switch (interval) {
      case 'Weekly':
        int daysToSubtract = now.weekday - 1; // Assumes Monday is 1
        startDate = DateTime(now.year, now.month, now.day - daysToSubtract);
        endDate = startDate.add(const Duration(days: 6));
        break;
      case 'Monthly':
        startDate = DateTime(now.year, now.month, 1);
        endDate = (now.month < 12)
            ? DateTime(now.year, now.month + 1, 0)
            : DateTime(now.year + 1, 1, 0);
        break;
      case 'Yearly':
        startDate = DateTime(now.year, 1, 1);
        endDate = DateTime(now.year, 12, 31);
        break;
      default:
        throw ArgumentError(
          "Budget analysis requires a 'Weekly', 'Monthly', or 'Yearly' interval.",
        );
    }

    startDate = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
      0,
      0,
      0,
    );
    startDate.add(const Duration(days: -30));
    endDate = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

    return DateTimeRange(start: startDate, end: endDate);
  }

  Future<Map<String, dynamic>?> analyzeBudgetForTag(
    Tag tag,
    Settings settings,
  ) async {
    if (tag.budgetAmount == null ||
        tag.budgetAmount! <= 0 ||
        tag.budgetInterval == 'None') {
      print(
        "Cannot analyze budget: No amount or interval set for tag '${tag.name}'.",
      );
      return null;
    }

    try {
      final budgetPeriod = _getCurrentBudgetPeriod(tag.budgetInterval);
      final transactionsForPeriod = getTransactionsForTagInRange(
        tag,
        budgetPeriod,
      );

      final serializedTransactions = transactionsForPeriod
          .map(
            (exp) => {
              'name': exp.articleName,
              'amount': exp.amount,
              'date': exp.date.toIso8601String().split('T').first,
              'is_income': exp.isIncome,
            },
          )
          .toList();

      final budgetDetails = {
        'category_name': tag.name,
        'amount': tag.budgetAmount,
        'interval': tag.budgetInterval,
        'start_date': budgetPeriod.start.toIso8601String().split('T').first,
      };

      final analysis = await _llmService.analyzeBudget(
        transactions: serializedTransactions,
        budgetDetails: budgetDetails,
        currentDate: DateTime.now().toIso8601String().split('T').first,
        budgetEndDate: budgetPeriod.end.toIso8601String().split('T').first,
        userContext: settings.userContext,
      );

      return analysis;
    } catch (e) {
      print("Error during budget analysis for tag '${tag.name}': $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> analyzeFullReport(
    ReportData reportData,
    DateTimeRange dateRange,
    Settings settings,
  ) async {
    List<Map<String, dynamic>> createBreakdownList(
      Map<Tag, TagReportData> sections,
    ) {
      return sections.entries.map((entry) {
        final Tag tag = entry.key;
        final TagReportData tagData = entry.value;
        return {'category': tag.name, 'amount': tagData.totalAmount};
      }).toList();
    }

    final incomeBreakdown = createBreakdownList(reportData.incomeByTag);
    final expenseBreakdown = createBreakdownList(reportData.expenseByTag);

    final SearchFilter filter = SearchFilter(
      startDate: dateRange.start,
      endDate: dateRange.end,
    );
    final List<Expenditure> transactionsInPeriod = getFilteredExpenditures(
      filter,
      false,
    );

    final serializedTransactions = transactionsInPeriod.map((exp) {
      final tagName = getTagById(exp.mainTagId)?.name ?? 'Uncategorized';
      return {
        'name': exp.articleName,
        'amount': exp.amount,
        'date': exp.date.toIso8601String().split('T').first,
        'is_income': exp.isIncome,
        'category': tagName,
      };
    }).toList();
    return await _llmService.analyzeFinancialReport(
      dateRangeStart: dateRange.start.toIso8601String().split('T').first,
      dateRangeEnd: dateRange.end.toIso8601String().split('T').first,
      userContext: settings.userContext,
      totalIncome: reportData.totalIncome,
      totalExpenses: reportData.totalExpense,
      incomeBreakdown: incomeBreakdown,
      expenseBreakdown: expenseBreakdown,
      transactionList: serializedTransactions,
    );
  }
}
