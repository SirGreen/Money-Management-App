import 'package:flutter/material.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:hive/hive.dart';
import 'package:test_app/app/controllers/assets_controller.dart';
import 'package:test_app/app/models/settings.dart';
import 'package:test_app/app/models/custom_exchange_rate.dart';
import 'package:test_app/app/services/database_service.dart';
import 'package:test_app/app/controllers/expenditure_controller.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:test_app/app/services/secure_storage_service.dart';
import 'package:test_app/app/services/encryption_service.dart';
import 'dart:typed_data';

enum ExportResult { success, cancelled, noPassword, failed }

enum ImportResult { success, cancelled, noPassword, wrongPassword, failed }

class SettingsController with ChangeNotifier {
  static const String settingsBoxName = 'settings';
  final DatabaseService _dbService = DatabaseService();
  late Settings _settings;
  List<CustomExchangeRate> _customRates = [];
  bool isInitialized = false;

  Settings get settings => _settings;
  List<CustomExchangeRate> get customRates => _customRates;

  DateTimeRange? reportDateRange;
  String lastExportPath = '';

  void updateConverterCurrencies({String? from, String? to}) {
    if (from != null) _settings.converterFromCurrency = from;
    if (to != null) _settings.converterToCurrency = to;
    saveSettings();
  }

  void updateReportDateRange(DateTimeRange newRange) {
    reportDateRange = newRange;
    notifyListeners();
  }

  SettingsController();

  Future<void> initialize() async {
    if (isInitialized) return;
    await _loadSettings();
    isInitialized = true;
  }

  Future<void> _loadSettings() async {
    final box = Hive.box<Settings>(settingsBoxName);
    _settings = box.get(0) ?? Settings();

    if (!_settings.isInBox) {
      await box.put(0, _settings);
    }

    _customRates = _dbService.getAllCustomRates();
    _customRates.sort((a, b) => a.conversionPair.compareTo(b.conversionPair));
    notifyListeners();
  }

  Future<void> saveSettings() async {
    await Hive.box<Settings>(settingsBoxName).put(0, _settings);
    notifyListeners();
  }

  Future<void> updateRemindersEnabled(bool isEnabled) async {
    _settings.remindersEnabled = isEnabled;
    await _settings.save();
    notifyListeners();
  }

  void updateDividerType(DividerType type) {
    _settings.dividerType = type;
    saveSettings();
  }

  void updatePaydayStartDay(int day) {
    _settings.paydayStartDay = day;
    saveSettings();
  }

  void updateFixedIntervalDays(int days) {
    _settings.fixedIntervalDays = days;
    saveSettings();
  }

  void updateLanguage(String? code) {
    _settings.languageCode = code;
    saveSettings();
  }

  void updatePaginationLimit(int limit) {
    _settings.paginationLimit = limit;
    saveSettings();
  }

  Future<void> updatePrimaryCurrency(
    ExpenditureController expenditureController,
    AssetsController assetsController,
    String newCode,
    Future<double?> Function(String, String) getRateCallback,
  ) async {
    final oldCode = _settings.primaryCurrencyCode;
    if (oldCode == newCode) return;
    final rate = await getRateCallback(oldCode, newCode);
    if (rate == null) {
      throw Exception("Failed to get exchange rate for $oldCode to $newCode");
    }
    await expenditureController.convertAllExpenditures(rate, newCode, settings);
    await assetsController.convertAllAssetData(rate);
    _settings.primaryCurrencyCode = newCode;
    await saveSettings();
  }

  Future<void> addOrUpdateCustomRate(
    String from,
    String to,
    double rate,
  ) async {
    final pair = "${from}_$to";
    final customRate = CustomExchangeRate(conversionPair: pair, rate: rate);
    await _dbService.saveCustomRate(customRate);
    await _loadSettings();
  }

  Future<void> deleteCustomRate(String pair) async {
    await _dbService.deleteCustomRate(pair);
    await _loadSettings();
  }

  Future<ExportResult> exportData(String password, String dialogTitle) async {
    try {
      if (password.isEmpty) return ExportResult.noPassword;

      final jsonString = await _dbService.exportAllDataToJson();
      final key = encrypt.Key.fromUtf8(password.padRight(32));
      final iv = encrypt.IV.fromLength(16);
      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      final encryptedData = encrypter.encrypt(jsonString, iv: iv);

      final bytes = iv.bytes + encryptedData.bytes;
      final Uint8List bytesToSave = Uint8List.fromList(bytes);

      final fileName =
          'kakeibo_backup_${DateFormat('yyyy-MM-dd-HH-mm').format(DateTime.now())}.kakeibo_backup';

      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: dialogTitle,
        fileName: fileName,
        bytes: bytesToSave,
      );

      if (outputFile == null && !(Platform.isAndroid || Platform.isIOS)) {
        return ExportResult.cancelled;
      }

      lastExportPath = outputFile ?? 'device storage';

      settings.lastBackupDate = DateTime.now();
      await saveSettings();

      return ExportResult.success;
    } catch (e) {
      print("Export failed: $e");
      return ExportResult.failed;
    }
  }

  Future<ImportResult> importData(
    File file,
    String? password,
    BuildContext context,
    ExpenditureController expenditureController,
    AssetsController assetsController,
  ) async {
    try {
      final allBytes = await file.readAsBytes();
      final isEncrypted = !file.path.endsWith('.json');
      String jsonString;

      if (isEncrypted) {
        if (password == null || password.isEmpty) {
          return ImportResult.noPassword;
        }
        try {
          final key = encrypt.Key.fromUtf8(password.padRight(32));
          final iv = encrypt.IV(allBytes.sublist(0, 16));
          final encryptedData = encrypt.Encrypted(allBytes.sublist(16));
          final encrypter = encrypt.Encrypter(encrypt.AES(key));
          jsonString = encrypter.decrypt(encryptedData, iv: iv);
        } catch (e) {
          return ImportResult.wrongPassword;
        }
      } else {
        jsonString = await file.readAsString();
      }

      _showLoadingDialog(context);

      final pin = await SecureStorageService().getPin();
      final isPinSet = pin != null;
      final encryptionKey = await EncryptionService.getEncryptionKey();
      final cipher = isPinSet ? HiveAesCipher(encryptionKey) : null;

      await Hive.close();
      await _dbService.openAllBoxes(encryptionCipher: cipher);
      await _dbService.importAllDataFromJson(jsonString);
      await initialize();
      await assetsController.initialize();

      if (context.mounted) Navigator.of(context).pop();
      Phoenix.rebirth(context);
      return ImportResult.success;
    } catch (e) {
      print("Import failed: $e");
      if (context.mounted) Navigator.of(context).pop();
      return ImportResult.failed;
    }
  }

  void _showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }

  bool shouldShowBackupReminder() {
    final lastBackup = settings.lastBackupDate;
    if (lastBackup == null) {
      return true;
    }
    final now = DateTime.now();
    return lastBackup.year < now.year || lastBackup.month < now.month;
  }

  Future<void> updateUserContext(String newContext) async {
    settings.userContext = newContext;
    await settings.save();
    notifyListeners();
  }
}
