// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saving_account.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SavingAccountAdapter extends TypeAdapter<SavingAccount> {
  @override
  final int typeId = 12;

  @override
  SavingAccount read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SavingAccount(
      id: fields[0] as String,
      name: fields[1] as String,
      balance: fields[2] as double,
      notes: fields[3] as String?,
      annualInterestRate: fields[4] as double?,
      startDate: fields[5] as DateTime,
      endDate: fields[6] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, SavingAccount obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.balance)
      ..writeByte(3)
      ..write(obj.notes)
      ..writeByte(4)
      ..write(obj.annualInterestRate)
      ..writeByte(5)
      ..write(obj.startDate)
      ..writeByte(6)
      ..write(obj.endDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavingAccountAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
