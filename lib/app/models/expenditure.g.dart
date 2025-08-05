// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expenditure.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ExpenditureAdapter extends TypeAdapter<Expenditure> {
  @override
  final int typeId = 0;

  @override
  Expenditure read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Expenditure(
      id: fields[0] as String,
      articleName: fields[1] as String,
      amount: fields[2] as double?,
      date: fields[3] as DateTime,
      mainTagId: fields[4] as String,
      isIncome: fields[8] as bool,
      subTagIds: (fields[5] as List).cast<String>(),
      receiptImagePath: fields[6] as String?,
      scheduledExpenditureId: fields[7] as String?,
      currencyCode: fields[9] as String,
      notes: fields[10] as String?,
    )
      ..createdAt = fields[11] as DateTime
      ..updatedAt = fields[12] as DateTime;
  }

  @override
  void write(BinaryWriter writer, Expenditure obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.articleName)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.date)
      ..writeByte(4)
      ..write(obj.mainTagId)
      ..writeByte(5)
      ..write(obj.subTagIds)
      ..writeByte(6)
      ..write(obj.receiptImagePath)
      ..writeByte(7)
      ..write(obj.scheduledExpenditureId)
      ..writeByte(8)
      ..write(obj.isIncome)
      ..writeByte(9)
      ..write(obj.currencyCode)
      ..writeByte(10)
      ..write(obj.notes)
      ..writeByte(11)
      ..write(obj.createdAt)
      ..writeByte(12)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExpenditureAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
