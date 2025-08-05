import 'package:test_app/app/services/database_service.dart';
import 'package:test_app/app/services/currency_api_service.dart';

class CurrencyService {
  final DatabaseService _dbService;
  final CurrencyAPIService _apiService;

  CurrencyService(this._dbService, this._apiService);

  Future<double?> getBestExchangeRate(String from, String to) async {
    final customRates = _dbService.getAllCustomRates();
    final pair = "${from}_$to";
    try {
      final customRate = customRates.firstWhere((r) => r.conversionPair == pair);
      return customRate.rate;
    } catch (e) {
      return await _apiService.getExchangeRate(from, to);
    }
  }

  Future<void> convertAllData(double rate, String newCurrencyCode) async {
    final allExpenditures = _dbService.getAllExpenditures();
    for (final exp in allExpenditures) {
      if (exp.amount != null) {
        exp.amount = exp.amount! * rate;
      }
      exp.currencyCode = newCurrencyCode;
      await _dbService.saveExpenditure(exp);
    }

    final allScheduled = _dbService.getAllScheduledExpenditures();
    for (final rule in allScheduled) {
      if (rule.amount != null) {
        rule.amount = rule.amount! * rate;
      }
      rule.currencyCode = newCurrencyCode;
      await _dbService.saveScheduledExpenditure(rule);
    }
    final allTags = _dbService.getAllTags();
    for (final tag in allTags) {
      if (tag.budgetAmount != null) {
        tag.budgetAmount = tag.budgetAmount! * rate;
      }
      await _dbService.saveTag(tag);
    }
  }
}