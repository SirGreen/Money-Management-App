import 'package:test_app/app/models/tag.dart';

enum TransactionTypeFilter { all, income, expense }

enum SortOption { dateDesc, dateAsc, amountDesc, amountAsc, nameAsc, nameDesc }

class SearchFilter {
  String? keyword;
  DateTime? startDate;
  DateTime? endDate;
  List<Tag>? tags;
  double? minAmount;
  double? maxAmount;
  TransactionTypeFilter transactionType;

  SearchFilter({
    this.keyword,
    this.startDate,
    this.endDate,
    this.tags,
    this.minAmount,
    this.maxAmount,
    this.transactionType = TransactionTypeFilter.all,
  });

  Map<String, dynamic> toJson() => {
    'keyword':keyword,
    'startDate':startDate,
    'endDate':endDate,
    'tags':tags,
    'minAmount':minAmount,
    'maxAmount':maxAmount,
    'transActionType':transactionType
  };
}