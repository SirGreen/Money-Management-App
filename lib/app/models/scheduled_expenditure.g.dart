// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scheduled_expenditure.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ScheduledExpenditureAdapter extends TypeAdapter<ScheduledExpenditure> {
  @override
  final int typeId = 4;

  @override
  ScheduledExpenditure read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ScheduledExpenditure(
      id: fields[0] as String,
      name: fields[1] as String,
      amount: fields[2] as double?,
      mainTagId: fields[3] as String,
      subTagIds: (fields[4] as List).cast<String>(),
      scheduleType: fields[5] as ScheduleType,
      scheduleValue: fields[6] as int,
      startDate: fields[7] as DateTime,
      lastCreatedDate: fields[8] as DateTime?,
      isActive: fields[9] as bool,
      endDate: fields[10] as DateTime?,
      isIncome: fields[11] as bool,
      currencyCode: fields[12] as String,
    );
  }

  @override
  void write(BinaryWriter writer, ScheduledExpenditure obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.mainTagId)
      ..writeByte(4)
      ..write(obj.subTagIds)
      ..writeByte(5)
      ..write(obj.scheduleType)
      ..writeByte(6)
      ..write(obj.scheduleValue)
      ..writeByte(7)
      ..write(obj.startDate)
      ..writeByte(8)
      ..write(obj.lastCreatedDate)
      ..writeByte(9)
      ..write(obj.isActive)
      ..writeByte(10)
      ..write(obj.endDate)
      ..writeByte(11)
      ..write(obj.isIncome)
      ..writeByte(12)
      ..write(obj.currencyCode);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScheduledExpenditureAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ScheduleTypeAdapter extends TypeAdapter<ScheduleType> {
  @override
  final int typeId = 5;

  @override
  ScheduleType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ScheduleType.dayOfMonth;
      case 1:
        return ScheduleType.endOfMonth;
      case 2:
        return ScheduleType.daysBeforeEndOfMonth;
      case 3:
        return ScheduleType.fixedInterval;
      default:
        return ScheduleType.dayOfMonth;
    }
  }

  @override
  void write(BinaryWriter writer, ScheduleType obj) {
    switch (obj) {
      case ScheduleType.dayOfMonth:
        writer.writeByte(0);
        break;
      case ScheduleType.endOfMonth:
        writer.writeByte(1);
        break;
      case ScheduleType.daysBeforeEndOfMonth:
        writer.writeByte(2);
        break;
      case ScheduleType.fixedInterval:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScheduleTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
