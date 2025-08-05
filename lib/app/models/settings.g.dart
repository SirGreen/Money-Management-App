// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SettingsAdapter extends TypeAdapter<Settings> {
  @override
  final int typeId = 2;

  @override
  Settings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Settings(
      dividerType: fields[0] as DividerType,
      paydayStartDay: fields[1] as int,
      fixedIntervalDays: fields[2] as int,
      languageCode: fields[3] as String?,
      paginationLimit: fields[4] as int,
      primaryCurrencyCode: fields[5] as String,
      converterFromCurrency: fields[6] as String,
      converterToCurrency: fields[7] as String,
      remindersEnabled: fields[8] as bool,
      lastBackupDate: fields[9] as DateTime?,
      userContext: fields[10] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Settings obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.dividerType)
      ..writeByte(1)
      ..write(obj.paydayStartDay)
      ..writeByte(2)
      ..write(obj.fixedIntervalDays)
      ..writeByte(3)
      ..write(obj.languageCode)
      ..writeByte(4)
      ..write(obj.paginationLimit)
      ..writeByte(5)
      ..write(obj.primaryCurrencyCode)
      ..writeByte(6)
      ..write(obj.converterFromCurrency)
      ..writeByte(7)
      ..write(obj.converterToCurrency)
      ..writeByte(8)
      ..write(obj.remindersEnabled)
      ..writeByte(9)
      ..write(obj.lastBackupDate)
      ..writeByte(10)
      ..write(obj.userContext);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DividerTypeAdapter extends TypeAdapter<DividerType> {
  @override
  final int typeId = 3;

  @override
  DividerType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return DividerType.monthly;
      case 1:
        return DividerType.paydayCycle;
      case 2:
        return DividerType.fixedInterval;
      default:
        return DividerType.monthly;
    }
  }

  @override
  void write(BinaryWriter writer, DividerType obj) {
    switch (obj) {
      case DividerType.monthly:
        writer.writeByte(0);
        break;
      case DividerType.paydayCycle:
        writer.writeByte(1);
        break;
      case DividerType.fixedInterval:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DividerTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
