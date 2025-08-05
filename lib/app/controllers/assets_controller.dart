import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:test_app/app/models/portfolio.dart';
import 'package:test_app/app/models/saving_account.dart';
import 'package:test_app/app/models/saving_goal.dart';
import 'package:test_app/app/models/investment.dart';
import 'package:test_app/app/services/database_service.dart';
import 'package:uuid/uuid.dart';

class AssetsController with ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  final Uuid _uuid = Uuid();

  List<SavingGoal> _savingGoals = [];
  List<SavingAccount> _savingAccounts = [];
  List<Portfolio> _portfolios = [];

  bool isInitialized = false;

  List<SavingGoal> get savingGoals => _savingGoals;
  List<SavingAccount> get savingAccounts => _savingAccounts;
  List<Portfolio> get portfolios => _portfolios;

  AssetsController();

  Future<void> initialize() async {
    if (isInitialized) return;
    await loadAssets();
    isInitialized = true;
  }

  Future<void> loadAssets() async {
    _savingGoals = _dbService.getAllSavingGoals();
    _savingAccounts = _dbService.getAllSavingAccounts();
    _portfolios = _dbService.getAllPortfolios();

    _savingGoals.sort((a, b) => a.name.compareTo(b.name));
    _savingAccounts.sort((a, b) => a.name.compareTo(b.name));

    notifyListeners();
  }

  Future<void> addSavingGoal({
    required String name,
    String? notes,
    required double targetAmount,
    required double currentAmount,
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    final newGoal = SavingGoal(
      id: _uuid.v4(),
      name: name,
      notes: notes,
      targetAmount: targetAmount,
      currentAmount: currentAmount,
      startDate: startDate,
      endDate: endDate,
    );
    await _dbService.saveSavingGoal(newGoal);
    await loadAssets();
  }

  Future<void> updateSavingGoal(SavingGoal goal) async {
    await _dbService.saveSavingGoal(goal);
    await loadAssets();
  }

  Future<void> deleteSavingGoal(String id) async {
    await _dbService.deleteSavingGoal(id);
    await loadAssets();
  }

  Future<void> addSavingAccount({
    required String name,
    required double balance,
    String? notes,
    required DateTime startDate,
    DateTime? endDate,
    double? annualInterestRate,
  }) async {
    final newAccount = SavingAccount(
      id: _uuid.v4(),
      name: name,
      balance: balance,
      notes: notes,
      startDate: startDate,
      endDate: endDate,
      annualInterestRate: annualInterestRate,
    );
    await _dbService.saveSavingAccount(newAccount);
    await loadAssets();
  }

  Future<void> updateSavingAccount(SavingAccount account) async {
    await _dbService.saveSavingAccount(account);
    await loadAssets();
  }

  Future<void> deleteSavingAccount(String id) async {
    await _dbService.deleteSavingAccount(id);
    await loadAssets();
  }

  Future<void> addPortfolio(String name) async {
    final newPortfolio = Portfolio(
      id: _uuid.v4(),
      name: name,
      investments: HiveList(_dbService.getInvestmentBox()),
    );
    await _dbService.savePortfolio(newPortfolio);
    await loadAssets();
  }

  Future<void> updatePortfolioName(Portfolio portfolio, String newName) async {
    portfolio.name = newName;
    await _dbService.savePortfolio(portfolio);
    await loadAssets();
  }

  Future<void> deletePortfolio(String id) async {
    await _dbService.deletePortfolio(id);
    await loadAssets();
  }

  Future<void> addInvestmentToPortfolio({
    required Portfolio portfolio,
    required String symbol,
    required String name,
    required double quantity,
    required double averageBuyPrice,
  }) async {
    final newInvestment = Investment(
      id: _uuid.v4(),
      symbol: symbol.toUpperCase(),
      name: name,
      quantity: quantity,
      averageBuyPrice: averageBuyPrice,
    );
    await _dbService.saveInvestment(newInvestment);
    portfolio.investments.add(newInvestment);
    await portfolio.save();
    await loadAssets();
  }

  Future<void> updateInvestment(Investment investment) async {
    await _dbService.saveInvestment(investment);
    await loadAssets();
  }

  Future<void> deleteInvestment(
    Portfolio portfolio,
    Investment investment,
  ) async {
    portfolio.investments.remove(investment);
    await portfolio.save();
    await _dbService.deleteInvestment(investment.id);
    await loadAssets();
  }

  Future<void> convertAllAssetData(double rate) async {
    for (final goal in _savingGoals) {
      goal.targetAmount *= rate;
      goal.currentAmount *= rate;
      await _dbService.saveSavingGoal(goal);
    }
    for (final account in _savingAccounts) {
      account.balance *= rate;
      await _dbService.saveSavingAccount(account);
    }
    for (final portfolio in _portfolios) {
      for (final investment in portfolio.investments) {
        investment.averageBuyPrice *= rate;
        if (investment.currentPrice != null) {
          investment.currentPrice = investment.currentPrice! * rate;
        }
        await _dbService.saveInvestment(investment);
      }
    }
    await loadAssets();
  }

  List<dynamic> getEndingSoonSavings() {
    final now = DateTime.now();
    final thirtyDaysFromNow = now.add(const Duration(days: 30));
    final List<dynamic> endingSoon = [];

    for (final goal in _savingGoals) {
      if (goal.endDate != null &&
          goal.endDate!.isAfter(now) &&
          goal.endDate!.isBefore(thirtyDaysFromNow)) {
        endingSoon.add(goal);
      }
    }

    for (final account in _savingAccounts) {
      if (account.endDate != null &&
          account.endDate!.isAfter(now) &&
          account.endDate!.isBefore(thirtyDaysFromNow)) {
        endingSoon.add(account);
      }
    }

    endingSoon.sort((a, b) => a.endDate!.compareTo(b.endDate!));

    return endingSoon;
  }
}
