import 'package:jiffy/jiffy.dart';
import 'package:test_app/app/models/expenditure.dart';
import 'package:test_app/app/models/scheduled_expenditure.dart';
import 'package:test_app/app/services/database_service.dart';
import 'package:test_app/app/utils/date_extensions.dart';
import 'package:uuid/uuid.dart';

class ScheduledExpenditureService {
  final DatabaseService _dbService;
  final Uuid _uuid = const Uuid();

  ScheduledExpenditureService(this._dbService);

  List<ScheduledExpenditure> getAllScheduledExpenditures() {
    return _dbService.getAllScheduledExpenditures();
  }

  Future<void> addScheduledExpenditure(ScheduledExpenditure scheduled) async {
    await _dbService.saveScheduledExpenditure(scheduled);
  }

  Future<void> updateScheduledExpenditure(
    ScheduledExpenditure scheduled, {
    bool updatePastAmounts = false,
  }) async {
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    if (scheduled.endDate != null && scheduled.endDate!.isBefore(today)) {
      scheduled.isActive = false;
    }

    final linkedExpenditures = _dbService
        .getAllExpenditures()
        .where((exp) => exp.scheduledExpenditureId == scheduled.id)
        .toList();

    for (final exp in linkedExpenditures) {
      bool needsSave = false;
      if (exp.isIncome != scheduled.isIncome) {
        exp.isIncome = scheduled.isIncome;
        needsSave = true;
      }
      if (exp.articleName != scheduled.name) {
        exp.articleName = scheduled.name;
        needsSave = true;
      }
      if (exp.mainTagId != scheduled.mainTagId) {
        exp.mainTagId = scheduled.mainTagId;
        needsSave = true;
      }
      if (!_listEquals(exp.subTagIds, scheduled.subTagIds)) {
        exp.subTagIds = List.from(scheduled.subTagIds);
        needsSave = true;
      }
      if (updatePastAmounts && exp.amount != scheduled.amount) {
        exp.amount = scheduled.amount;
        needsSave = true;
      }
      if (needsSave) {
        await _dbService.saveExpenditure(exp);
      }
    }
    await _dbService.saveScheduledExpenditure(scheduled);
  }

  Future<void> deleteScheduledExpenditure(
    String id, {
    required bool deleteInstances,
  }) async {
    final linkedExpenditures = _dbService
        .getAllExpenditures()
        .where((exp) => exp.scheduledExpenditureId == id)
        .toList();

    if (deleteInstances) {
      final idsToDelete = linkedExpenditures.map((exp) => exp.id).toList();
      if (idsToDelete.isNotEmpty) {
        await _dbService.deleteExpenditures(idsToDelete);
      }
    } else {
      for (final exp in linkedExpenditures) {
        exp.scheduledExpenditureId = null;
        await _dbService.saveExpenditure(exp);
      }
    }

    await _dbService.deleteScheduledExpenditure(id);
  }

  Future<bool> processScheduledExpenditures() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    bool createdAny = false;
    final allRules = _dbService.getAllScheduledExpenditures();
    for (final rule in allRules) {
      if (!rule.isActive) continue;
      if (rule.endDate != null && rule.endDate!.isBefore(today)) {
        rule.isActive = false;
        await _dbService.saveScheduledExpenditure(rule);
        continue;
      }
      DateTime checkDate = rule.lastCreatedDate != null
          ? rule.lastCreatedDate!.add(const Duration(days: 1))
          : rule.startDate;
      // print("checkDate: $checkDate");
      while (true) {
        DateTime? nextDueDate = _calculateNextDueDate(checkDate, rule);
        // print("nextDueDate: $nextDueDate");
        if (nextDueDate == null ||
            (nextDueDate.isAfter(now) && !nextDueDate.isSameDate(now))) {
          break;
        }
        // print("check1");
        if (rule.endDate != null && nextDueDate.isAfter(rule.endDate!)) break;
        // print("check2");

        if (nextDueDate.isBefore(rule.startDate)) {
          checkDate = nextDueDate.add(const Duration(days: 1));
          continue;
        }
        // print("check3");

        final newExpenditure = Expenditure(
          id: _uuid.v4(),
          articleName: rule.name,
          amount: rule.amount,
          date: nextDueDate,
          mainTagId: rule.mainTagId,
          subTagIds: rule.subTagIds,
          isIncome: rule.isIncome,
          scheduledExpenditureId: rule.id,
          currencyCode: rule.currencyCode,
        );

        await _dbService.saveExpenditure(newExpenditure);
        createdAny = true;

        rule.lastCreatedDate = nextDueDate;
        await _dbService.saveScheduledExpenditure(rule);

        checkDate = nextDueDate.add(const Duration(days: 1));
      }
    }
    return createdAny;
  }

  List<ScheduledExpenditure> getUpcomingScheduledTransactions(
    List<ScheduledExpenditure> allScheduled,
  ) {
    final now = DateTime.now();
    final upcoming = <ScheduledExpenditure>[];

    for (final rule in allScheduled) {
      if (!rule.isActive) continue;
      DateTime checkDate = rule.lastCreatedDate ?? rule.startDate;
      DateTime? nextDueDate = _calculateNextDueDate(checkDate, rule);
      if (nextDueDate != null &&
          nextDueDate.isAfter(now) &&
          nextDueDate.difference(now).inDays <= 7) {
        upcoming.add(rule);
      }
    }

    upcoming.sort((a, b) {
      final aDate = _calculateNextDueDate(a.lastCreatedDate ?? a.startDate, a)!;
      final bDate = _calculateNextDueDate(b.lastCreatedDate ?? b.startDate, b)!;
      return aDate.compareTo(bDate);
    });

    return upcoming;
  }

  DateTime? _calculateNextDueDate(DateTime from, ScheduledExpenditure rule) {
    switch (rule.scheduleType) {
      case ScheduleType.dayOfMonth:
        var potentialDueDate = DateTime(
          from.year,
          from.month,
          rule.scheduleValue,
        );
        if (potentialDueDate.isBefore(from)) {
          return Jiffy.parseFromDateTime(
            potentialDueDate,
          ).add(months: 1).dateTime;
        }
        return potentialDueDate;

      case ScheduleType.endOfMonth:
        var endOfCurrentMonth = Jiffy.parseFromDateTime(
          from,
        ).endOf(Unit.month).dateTime;
        if (endOfCurrentMonth.isBefore(from)) {
          return Jiffy.parseFromDateTime(
            from,
          ).add(months: 1).endOf(Unit.month).dateTime;
        }
        return endOfCurrentMonth;

      case ScheduleType.daysBeforeEndOfMonth:
        var endOfMonth = Jiffy.parseFromDateTime(
          from,
        ).endOf(Unit.month).dateTime;
        var potentialDueDate = endOfMonth.subtract(
          Duration(days: rule.scheduleValue),
        );
        if (potentialDueDate.isBefore(from)) {
          return Jiffy.parseFromDateTime(from)
              .add(months: 1)
              .endOf(Unit.month)
              .dateTime
              .subtract(Duration(days: rule.scheduleValue));
        }
        return potentialDueDate;

      case ScheduleType.fixedInterval:
        if (from.isBefore(rule.startDate)) {
          return rule.startDate;
        }
        final daysSinceStart = from.difference(rule.startDate).inDays;
        final remainder = daysSinceStart % rule.scheduleValue;
        if (remainder == 0) return from;
        final daysToAdd = rule.scheduleValue - remainder;
        return from.add(Duration(days: daysToAdd));
    }
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    return a.toSet().containsAll(b);
  }
}
