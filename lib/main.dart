import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:path/path.dart' as path;
import 'package:test_app/app/controllers/assets_controller.dart';
import 'package:test_app/app/controllers/expenditure_controller.dart';
import 'package:test_app/app/controllers/settings_controller.dart';
import 'package:test_app/app/models/cached_rate.dart';
import 'package:test_app/app/models/custom_exchange_rate.dart';
import 'package:test_app/app/models/expenditure.dart';
import 'package:test_app/app/models/investment.dart';
import 'package:test_app/app/models/portfolio.dart';
import 'package:test_app/app/models/saving_account.dart';
import 'package:test_app/app/models/saving_goal.dart';
import 'package:test_app/app/models/scheduled_expenditure.dart';
import 'package:test_app/app/models/settings.dart';
import 'package:test_app/app/models/tag.dart';
import 'package:test_app/app/services/database_service.dart';
import 'package:test_app/app/services/encryption_service.dart';
import 'package:test_app/app/services/secure_storage_service.dart';
import 'package:test_app/app/views/main_page.dart';
import 'package:test_app/app/views/pin_lock_page.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:test_app/l10n/app_localizations.dart';
import 'package:test_app/app/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await initializeDateFormatting('ja', null);
    await initializeDateFormatting('en', null);
    await initializeDateFormatting('vi', null);

    await Hive.initFlutter();

    Hive.registerAdapter(ExpenditureAdapter());
    Hive.registerAdapter(TagAdapter());
    Hive.registerAdapter(SettingsAdapter());
    Hive.registerAdapter(DividerTypeAdapter());
    Hive.registerAdapter(ScheduledExpenditureAdapter());
    Hive.registerAdapter(ScheduleTypeAdapter());
    Hive.registerAdapter(CustomExchangeRateAdapter());
    Hive.registerAdapter(CachedRateAdapter());
    Hive.registerAdapter(SavingGoalAdapter());
    Hive.registerAdapter(SavingAccountAdapter());
    Hive.registerAdapter(InvestmentAdapter());
    Hive.registerAdapter(PortfolioAdapter());

    await NotificationService().initForApp();
  } catch (e, stack) {
    debugPrint('Initialization error: $e\n$stack');
  }
  runApp(Phoenix(child: const AppRoot()));
}

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => SettingsController()),
        ChangeNotifierProvider(create: (context) => AssetsController()),
        ChangeNotifierProvider(create: (context) => ExpenditureController()),
      ],
      child: const AppLifecycleManager(),
    );
  }
}

class AppLifecycleManager extends StatefulWidget {
  const AppLifecycleManager({super.key});

  @override
  State<AppLifecycleManager> createState() => _AppLifecycleManagerState();
}

class _AppLifecycleManagerState extends State<AppLifecycleManager>
    with WidgetsBindingObserver {
  bool _isLocked = true;
  bool _pinIsSet = false;
  bool _isInitialized = false;

  final NotificationService _notificationService = NotificationService();
  AppLocalizations? _l10n;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    Hive.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      if (_pinIsSet && !_isLocked) {
        setState(() {
          _isLocked = true;
        });
      }
      debugPrint("App is paused. Checking for incomplete transactions...");
      _handleIncompleteTransactionNotifications();
    }
  }

  Future<void> _handleLoginNotifications() async {
    final settings = Provider.of<SettingsController>(
      context,
      listen: false,
    ).settings;
    if (_l10n == null || !settings.remindersEnabled) return;

    await _notificationService.cancelDailyLoginReminder();
    await _notificationService.scheduleDailyLoginReminder(
      title: _l10n!.notificationReminderTitle,
      body: _l10n!.notificationReminderBody,
      hour: 20, // 8 PM
      minute: 0,
    );
  }

  Future<void> _handleIncompleteTransactionNotifications() async {
    final settings = Provider.of<SettingsController>(
      context,
      listen: false,
    ).settings;
    if (_l10n == null || !mounted || !settings.remindersEnabled) return;

    final expenditureController = Provider.of<ExpenditureController>(
      context,
      listen: false,
    );

    await _notificationService.cancelIncompleteItemsReminder();

    final incompleteCount = expenditureController
        .getIncompleteTransactionsTodayCount();

    if (incompleteCount > 0) {
      await _notificationService.scheduleIncompleteItemsReminder(
        title: _l10n!.notificationIncompleteTitle,
        body: _l10n!.notificationIncompleteBody(incompleteCount),
        hour: 21, // 9 PM
        minute: 0,
      );
    }
  }

  Future<void> _initializeApp() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final importFile = File(path.join(tempDir.path, 'import_data.json'));
      final secureStorage = SecureStorageService();
      final dbService = DatabaseService();
      String? jsonToImport;
      String? preservedPin = await secureStorage.getPin();

      if (await importFile.exists()) {
        jsonToImport = await importFile.readAsString();
        await importFile.delete();
        await Hive.deleteFromDisk();
      }

      final bool shouldBeEncrypted = preservedPin != null;
      final encryptionKey = await EncryptionService.getEncryptionKey();
      final cipher = shouldBeEncrypted ? HiveAesCipher(encryptionKey) : null;
      await dbService.openAllBoxes(encryptionCipher: cipher);

      if (jsonToImport != null) {
        await dbService.importAllDataFromJson(jsonToImport);
      }

      final pinAfterSetup = await secureStorage.getPin();
      final isPinSet = pinAfterSetup != null;

      final settingsController = Provider.of<SettingsController>(
        context,
        listen: false,
      );
      await settingsController.initialize();

      final assetsController = Provider.of<AssetsController>(
        context,
        listen: false,
      );
      await assetsController.initialize();

      final expenditureController = Provider.of<ExpenditureController>(
        context,
        listen: false,
      );
      final locale = settingsController.settings.languageCode != null
          ? Locale(settingsController.settings.languageCode!)
          : WidgetsBinding.instance.platformDispatcher.locale;

      _l10n = await AppLocalizations.delegate.load(locale);
      await expenditureController.initialize(_l10n!, settingsController.settings);

      await _handleLoginNotifications();
      await _handleIncompleteTransactionNotifications();

      if (mounted) {
        setState(() {
          _pinIsSet = isPinSet;
          _isLocked = isPinSet;
          _isInitialized = true;
        });
      }
    } catch (e, stack) {
      debugPrint('App initialization error: $e\n$stack');
    }
  }

  void onUnlock() {
    setState(() {
      _isLocked = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return Consumer<SettingsController>(
      builder: (context, settingsController, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          onGenerateTitle: (context) =>
              AppLocalizations.of(context)?.appName ?? 'Kakeibo',
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
            inputDecorationTheme: const InputDecorationTheme(
              border: OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.teal, width: 2.0),
              ),
            ),
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: settingsController.settings.languageCode != null
              ? Locale(settingsController.settings.languageCode!)
              : null,
          home: _isLocked ? PinLockPage(onUnlock: onUnlock) : const MainPage(),
        );
      },
    );
  }
}
