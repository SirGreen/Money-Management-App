class BudgetStatus {
  final double spent;
  final double budget;
  final double progress;
  final bool isOverBudget;
  final int transactionCount;
  final DateTime resetDate;

  BudgetStatus({
    required this.spent,
    required this.budget,
    required this.progress,
    required this.isOverBudget,
    required this.transactionCount,
    required this.resetDate,
  });
}