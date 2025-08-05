import 'dart:convert';
import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:test_app/app/models/cached_rate.dart';
import 'package:test_app/app/models/custom_exchange_rate.dart';
import 'package:test_app/app/models/expenditure.dart';
import 'package:test_app/app/models/investment.dart';
import 'package:test_app/app/models/portfolio.dart';
import 'package:test_app/app/models/saving_account.dart';
import 'package:test_app/app/models/saving_goal.dart';
import 'package:test_app/app/models/scheduled_expenditure.dart';
import 'package:test_app/app/models/settings.dart';
import 'package:test_app/app/models/tag.dart';
import 'package:test_app/app/services/secure_storage_service.dart';

class DatabaseService {
  static const String expenditureBoxName = 'expenditures';
  static const String tagBoxName = 'tags';
  static const String scheduledExpenditureBoxName = 'scheduled_expenditures';
  static const String settingsBoxName = 'settings';
  static const String customRateBoxName = 'custom_rates';
  static const String cachedRateBoxName = 'cached_rates';
  static const String savingGoalBoxName = 'saving_goals';
  static const String investmentBoxName = 'investments';
  static const String portfolioBoxName = 'portfolios';
  static const String savingAccountBoxName = 'saving_accounts';

  Future<void> openAllBoxes({HiveCipher? encryptionCipher}) async {
    await Hive.openBox<Expenditure>(
      expenditureBoxName,
      encryptionCipher: encryptionCipher,
    );
    await Hive.openBox<Tag>(tagBoxName, encryptionCipher: encryptionCipher);
    await Hive.openBox<ScheduledExpenditure>(
      scheduledExpenditureBoxName,
      encryptionCipher: encryptionCipher,
    );
    await Hive.openBox<Settings>(
      settingsBoxName,
      encryptionCipher: encryptionCipher,
    );
    await Hive.openBox<CustomExchangeRate>(
      customRateBoxName,
      encryptionCipher: encryptionCipher,
    );
    await Hive.openBox<CachedRate>(
      cachedRateBoxName,
      encryptionCipher: encryptionCipher,
    );
    await Hive.openBox<SavingGoal>(
      savingGoalBoxName,
      encryptionCipher: encryptionCipher,
    );
    await Hive.openBox<SavingAccount>(
      savingAccountBoxName,
      encryptionCipher: encryptionCipher,
    );
    await Hive.openBox<Investment>(
      investmentBoxName,
      encryptionCipher: encryptionCipher,
    );
    await Hive.openBox<Portfolio>(
      portfolioBoxName,
      encryptionCipher: encryptionCipher,
    );
  }

  Future<void> migrateToEncrypted(HiveCipher encryptionCipher) async {
    print("Starting migration to encrypted database...");
    final allData = await exportAllDataToMap();
    await Hive.close();
    await openAllBoxes(encryptionCipher: encryptionCipher);
    await importAllDataFromMap(allData);
    print("Migration to encrypted database complete.");
  }

  Future<void> migrateToUnencrypted() async {
    print("Starting migration to unencrypted database...");
    final allData = await exportAllDataToMap();
    await Hive.close();
    await openAllBoxes(encryptionCipher: null);
    await importAllDataFromMap(allData);
    print("Migration to unencrypted database complete.");
  }

  Future<void> deleteAllDataAndReset() async {
    try {
      await Hive.close();
      await SecureStorageService().deletePin();
      final appDir = await getApplicationDocumentsDirectory();
      final dbPath = appDir.path;

      final boxFiles = [
        File('$dbPath/$expenditureBoxName.hive'),
        File('$dbPath/$expenditureBoxName.lock'),
        File('$dbPath/$tagBoxName.hive'),
        File('$dbPath/$tagBoxName.lock'),
        File('$dbPath/$scheduledExpenditureBoxName.hive'),
        File('$dbPath/$scheduledExpenditureBoxName.lock'),
        File('$dbPath/$settingsBoxName.hive'),
        File('$dbPath/$settingsBoxName.lock'),
        File('$dbPath/$customRateBoxName.hive'),
        File('$dbPath/$customRateBoxName.lock'),
        File('$dbPath/$cachedRateBoxName.hive'),
        File('$dbPath/$cachedRateBoxName.lock'),
        File('$dbPath/$savingGoalBoxName.hive'),
        File('$dbPath/$savingGoalBoxName.lock'),
        File('$dbPath/$investmentBoxName.hive'),
        File('$dbPath/$investmentBoxName.lock'),
        File('$dbPath/$portfolioBoxName.hive'),
        File('$dbPath/$portfolioBoxName.lock'),
        File('$dbPath/$savingAccountBoxName.hive'),
        File('$dbPath/$savingAccountBoxName.lock'),
      ];

      for (final file in boxFiles) {
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      print("Error resetting all data: $e");
    }
  }

  Future<Map<String, dynamic>> exportAllDataToMap() async {
    final Map<String, dynamic> allData = {};
    allData['expenditures'] = Hive.box<Expenditure>(
      expenditureBoxName,
    ).values.map((e) => e.toJson()).toList();
    allData['tags'] = Hive.box<Tag>(
      tagBoxName,
    ).values.map((t) => t.toJson()).toList();
    allData['scheduled_expenditures'] = Hive.box<ScheduledExpenditure>(
      scheduledExpenditureBoxName,
    ).values.map((s) => s.toJson()).toList();
    allData['settings'] = Hive.box<Settings>(settingsBoxName).get(0)?.toJson();
    allData['custom_rates'] = Hive.box<CustomExchangeRate>(
      customRateBoxName,
    ).values.map((r) => r.toJson()).toList();
    allData['cached_rates'] = Hive.box<CachedRate>(
      cachedRateBoxName,
    ).get('latest_rates')?.toJson();
    allData['saving_goals'] = Hive.box<SavingGoal>(
      savingGoalBoxName,
    ).values.map((g) => g.toJson()).toList();
    allData['saving_accounts'] = Hive.box<SavingAccount>(
      savingAccountBoxName,
    ).values.map((a) => a.toJson()).toList();
    allData['investments'] = Hive.box<Investment>(
      investmentBoxName,
    ).values.map((i) => i.toJson()).toList();
    allData['portfolios'] = Hive.box<Portfolio>(
      portfolioBoxName,
    ).values.map((p) => p.toJson()).toList();
    return allData;
  }

  Future<void> importAllDataFromMap(Map<String, dynamic> allData) async {
    if (allData['expenditures'] is List) {
      final box = Hive.box<Expenditure>(expenditureBoxName);
      for (var itemJson in allData['expenditures']) {
        await box.put(itemJson['id'], Expenditure.fromJson(itemJson));
      }
    }
    if (allData['tags'] is List) {
      final box = Hive.box<Tag>(tagBoxName);
      for (var itemJson in allData['tags']) {
        await box.put(itemJson['id'], Tag.fromJson(itemJson));
      }
    }
    if (allData['scheduled_expenditures'] is List) {
      final box = Hive.box<ScheduledExpenditure>(scheduledExpenditureBoxName);
      for (var itemJson in allData['scheduled_expenditures']) {
        await box.put(itemJson['id'], ScheduledExpenditure.fromJson(itemJson));
      }
    }
    if (allData['settings'] is Map) {
      final box = Hive.box<Settings>(settingsBoxName);
      await box.put(0, Settings.fromJson(allData['settings']));
    }
    if (allData['custom_rates'] is List) {
      final box = Hive.box<CustomExchangeRate>(customRateBoxName);
      for (var itemJson in allData['custom_rates']) {
        await box.put(
          itemJson['conversionPair'],
          CustomExchangeRate.fromJson(itemJson),
        );
      }
    }
    if (allData['cached_rates'] is Map) {
      final box = Hive.box<CachedRate>(cachedRateBoxName);
      await box.put(
        'latest_rates',
        CachedRate.fromJson(allData['cached_rates']),
      );
    }
    if (allData['saving_goals'] is List) {
      final box = Hive.box<SavingGoal>(savingGoalBoxName);
      for (var itemJson in allData['saving_goals']) {
        await box.put(itemJson['id'], SavingGoal.fromJson(itemJson));
      }
    }
    if (allData['saving_accounts'] is List) {
      final box = Hive.box<SavingAccount>(savingAccountBoxName);
      for (var itemJson in allData['saving_accounts']) {
        await box.put(itemJson['id'], SavingAccount.fromJson(itemJson));
      }
    }
    if (allData['investments'] is List) {
      final box = Hive.box<Investment>(investmentBoxName);
      for (var itemJson in allData['investments']) {
        await box.put(itemJson['id'], Investment.fromJson(itemJson));
      }
    }
    if (allData['portfolios'] is List) {
      final box = Hive.box<Portfolio>(portfolioBoxName);
      for (var itemJson in allData['portfolios']) {
        await box.put(itemJson['id'], Portfolio.fromJson(itemJson));
      }
    }
  }

  List<Expenditure> getAllExpenditures() {
    return Hive.box<Expenditure>(expenditureBoxName).values.toList();
  }

  Future<void> saveExpenditure(Expenditure exp) async {
    await Hive.box<Expenditure>(expenditureBoxName).put(exp.id, exp);
  }

  Future<void> deleteExpenditure(String id) async {
    await Hive.box<Expenditure>(expenditureBoxName).delete(id);
  }

  List<String> getAllExpenditureIdsSortedByDate() {
    var allItems = getAllExpenditures();
    allItems.sort((a, b) => b.date.compareTo(a.date));
    return allItems.map((e) => e.id).toList();
  }

  Expenditure? getExpenditureById(String id) {
    return Hive.box<Expenditure>(expenditureBoxName).get(id);
  }

  Future<void> deleteExpenditures(List<String> ids) async {
    await Hive.box<Expenditure>(expenditureBoxName).deleteAll(ids);
  }

  List<Expenditure> getExpendituresByIds(List<String> ids) {
    final box = Hive.box<Expenditure>(expenditureBoxName);
    final List<Expenditure> result = [];
    for (final id in ids) {
      final exp = box.get(id);
      if (exp != null) result.add(exp);
    }
    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  List<Tag> getAllTags() {
    return Hive.box<Tag>(tagBoxName).values.toList();
  }

  Future<void> saveTag(Tag tag) async {
    await Hive.box<Tag>(tagBoxName).put(tag.id, tag);
  }

  Future<void> deleteTag(String id) async {
    await Hive.box<Tag>(tagBoxName).delete(id);
  }

  List<ScheduledExpenditure> getAllScheduledExpenditures() {
    return Hive.box<ScheduledExpenditure>(
      scheduledExpenditureBoxName,
    ).values.toList();
  }

  Future<void> saveScheduledExpenditure(ScheduledExpenditure scheduled) async {
    await Hive.box<ScheduledExpenditure>(
      scheduledExpenditureBoxName,
    ).put(scheduled.id, scheduled);
  }


  Future<void> deleteScheduledExpenditure(String id) async {
    await Hive.box<ScheduledExpenditure>(
      scheduledExpenditureBoxName,
    ).delete(id);
  }

  List<CustomExchangeRate> getAllCustomRates() {
    return Hive.box<CustomExchangeRate>(customRateBoxName).values.toList();
  }

  Future<void> saveCustomRate(CustomExchangeRate rate) async {
    await Hive.box<CustomExchangeRate>(
      customRateBoxName,
    ).put(rate.conversionPair, rate);
  }

  Future<void> deleteCustomRate(String conversionPair) async {
    await Hive.box<CustomExchangeRate>(
      customRateBoxName,
    ).delete(conversionPair);
  }

  List<SavingGoal> getAllSavingGoals() {
    return Hive.box<SavingGoal>(savingGoalBoxName).values.toList();
  }

  Future<void> saveSavingGoal(SavingGoal goal) async {
    await Hive.box<SavingGoal>(savingGoalBoxName).put(goal.id, goal);
  }

  Future<void> deleteSavingGoal(String id) async {
    await Hive.box<SavingGoal>(savingGoalBoxName).delete(id);
  }

  List<SavingAccount> getAllSavingAccounts() {
    return Hive.box<SavingAccount>(savingAccountBoxName).values.toList();
  }

  Future<void> saveSavingAccount(SavingAccount account) async {
    await Hive.box<SavingAccount>(
      savingAccountBoxName,
    ).put(account.id, account);
  }

  Future<void> deleteSavingAccount(String id) async {
    await Hive.box<SavingAccount>(savingAccountBoxName).delete(id);
  }

  List<Portfolio> getAllPortfolios() {
    return Hive.box<Portfolio>(portfolioBoxName).values.toList();
  }

  Future<void> savePortfolio(Portfolio portfolio) async {
    await Hive.box<Portfolio>(portfolioBoxName).put(portfolio.id, portfolio);
  }

  Future<void> deletePortfolio(String id) async {
    await Hive.box<Portfolio>(portfolioBoxName).delete(id);
  }

  Box<Investment> getInvestmentBox() {
    return Hive.box<Investment>(investmentBoxName);
  }

  Future<void> saveInvestment(Investment investment) async {
    await Hive.box<Investment>(
      investmentBoxName,
    ).put(investment.id, investment);
  }

  Future<void> deleteInvestment(String id) async {
    await Hive.box<Investment>(investmentBoxName).delete(id);
  }

  Future<void> deleteAllData() async {
    await Hive.box<Expenditure>(expenditureBoxName).clear();
    await Hive.box<Tag>(tagBoxName).clear();
    await Hive.box<ScheduledExpenditure>(scheduledExpenditureBoxName).clear();
    await Hive.box<Settings>(settingsBoxName).clear();
    await Hive.box<CustomExchangeRate>(customRateBoxName).clear();
    await Hive.box<CachedRate>(cachedRateBoxName).clear();
    await Hive.box<SavingGoal>(savingGoalBoxName).clear();
    await Hive.box<SavingAccount>(savingAccountBoxName).clear();
    await Hive.box<Portfolio>(portfolioBoxName).clear();
    await Hive.box<Investment>(investmentBoxName).clear();
  }

  Future<String> exportAllDataToJson() async {
    final allData = await exportAllDataToMap();
    return const JsonEncoder.withIndent('  ').convert(allData);
  }

  Future<void> importAllDataFromJson(String jsonString) async {
    await deleteAllData();
    final Map<String, dynamic> allData = jsonDecode(jsonString);
    await importAllDataFromMap(allData);
  }
}