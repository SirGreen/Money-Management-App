// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cached_rate.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CachedRateAdapter extends TypeAdapter<CachedRate> {
  @override
  final int typeId = 8;

  @override
  CachedRate read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CachedRate(
      baseCode: fields[0] as String,
      conversionRates: (fields[1] as Map).cast<String, double>(),
      lastFetched: fields[2] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, CachedRate obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.baseCode)
      ..writeByte(1)
      ..write(obj.conversionRates)
      ..writeByte(2)
      ..write(obj.lastFetched);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CachedRateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
