// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'custom_exchange_rate.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CustomExchangeRateAdapter extends TypeAdapter<CustomExchangeRate> {
  @override
  final int typeId = 7;

  @override
  CustomExchangeRate read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CustomExchangeRate(
      conversionPair: fields[0] as String,
      rate: fields[1] as double,
    );
  }

  @override
  void write(BinaryWriter writer, CustomExchangeRate obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.conversionPair)
      ..writeByte(1)
      ..write(obj.rate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomExchangeRateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
