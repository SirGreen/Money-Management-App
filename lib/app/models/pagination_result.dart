import 'package:test_app/app/models/expenditure.dart';

class PaginationResult {
  final List<Expenditure> expenditures;

  final bool hasMore;

  PaginationResult({
    required this.expenditures,
    required this.hasMore,
  });
}