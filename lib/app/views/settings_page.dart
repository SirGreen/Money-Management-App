import 'dart:io';
import 'dart:ui';
import 'package:app_settings/app_settings.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:provider/provider.dart';
import 'package:test_app/app/controllers/assets_controller.dart';
import 'package:test_app/app/controllers/expenditure_controller.dart';
import 'package:test_app/app/controllers/settings_controller.dart';
import 'package:test_app/app/models/settings.dart';
import 'package:test_app/app/services/database_service.dart';
import 'package:test_app/app/services/notification_service.dart';
import 'package:test_app/app/services/secure_storage_service.dart';
import 'package:test_app/app/views/create_pin_page.dart';
import 'package:test_app/app/views/helpers/glass_card.dart';
import 'package:test_app/app/views/helpers/gradient_background.dart';
import 'package:test_app/app/views/helpers/gradient_title.dart';
import 'package:test_app/app/views/helpers/section_header.dart';
import 'package:test_app/l10n/app_localizations.dart';
import 'package:test_app/app/views/edit_user_context_page.dart';

class SettingsAppBar extends StatelessWidget implements PreferredSizeWidget {
  final AppLocalizations l10n;

  const SettingsAppBar({super.key, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: AppBar(
          title: GradientTitle(text: l10n.settings),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.white.withOpacity(0.2),
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(32),
            ),
            side: BorderSide(color: Colors.white.withOpacity(0.3)),
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with WidgetsBindingObserver {
  final NotificationService _notificationService = NotificationService();
  bool _areRemindersEnabledByPermission = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkNotificationStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _checkNotificationStatus();
    }
  }

  Future<void> _checkNotificationStatus() async {
    final bool isEnabled = await _notificationService.areNotificationsEnabled();
    if (mounted) {
      setState(() => _areRemindersEnabledByPermission = isEnabled);
    }
  }

  Future<void> _onReminderSwitchChanged(
    bool value,
    SettingsController controller,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    if (value) {
      final bool granted = await _notificationService.requestPermissions();
      if (mounted) setState(() => _areRemindersEnabledByPermission = granted);
      if (granted) {
        await controller.updateRemindersEnabled(true);
      } else {
        await controller.updateRemindersEnabled(false);
        if (mounted) {
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(l10n.permissionDenied),
              content: Text(l10n.notificationPermissionGuide),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.cancel),
                ),
                TextButton(
                  onPressed: () {
                    AppSettings.openAppSettings(
                      type: AppSettingsType.notification,
                    );
                    Navigator.pop(context);
                  },
                  child: Text(l10n.openSettings),
                ),
              ],
            ),
          );
        }
      }
    } else {
      await controller.updateRemindersEnabled(false);
      await _notificationService.cancelDailyLoginReminder();
      await _notificationService.cancelIncompleteItemsReminder();
    }
  }

  Future<String?> _showPasswordDialog(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l10n.backupPassword),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: passwordController,
            obscureText: true,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.password,
              hintText: l10n.enterPasswordForBackup,
              border: const OutlineInputBorder(),
            ),
            validator: (value) => (value == null || value.isEmpty)
                ? l10n.passwordCannotBeEmpty
                : null,
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: Text(l10n.cancel),
            onPressed: () => Navigator.of(context).pop(),
          ),
          FilledButton(
            child: Text(l10n.ok),
            onPressed: () {
              if (formKey.currentState!.validate())
                Navigator.of(context).pop(passwordController.text);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _handleExport(
    BuildContext context,
    SettingsController controller,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final password = await _showPasswordDialog(context, l10n);
    if (password == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.exportCancelled)));
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.exportingData)));
    final result = await controller.exportData(password, l10n.selectOutputFile);
    if (mounted) {
      final String message;
      switch (result) {
        case ExportResult.success:
          message = l10n.exportSuccess(controller.lastExportPath);
          break;
        case ExportResult.cancelled:
          message = l10n.exportCancelled;
          break;
        case ExportResult.noPassword:
          message = l10n.exportNoPassword;
          break;
        case ExportResult.failed:
          message = l10n.exportFailed;
          break;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _handleImport(
    BuildContext context,
    SettingsController controller,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final bool? proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.warning),
        content: Text(l10n.importWarningMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            child: Text(l10n.proceed),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (proceed != true) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.importCancelled)));
      }
      return;
    }
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );
    if (result == null || result.files.single.path == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.importCancelled)));
      }
      return;
    }
    final bool isEncrypted = result.files.single.extension != 'json';
    String? password;
    if (isEncrypted) {
      if (!mounted) return;
      password = await _showPasswordDialog(context, l10n);
      if (password == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.importCancelled)));
          return;
        }
      }
    }
    if (!mounted) return;
    final expenditureController = Provider.of<ExpenditureController>(
      context,
      listen: false,
    );
    final assetsController = Provider.of<AssetsController>(
      context,
      listen: false,
    );
    final File file = File(result.files.single.path!);
    if (!mounted) return;
    final importResult = await controller.importData(
      file,
      password,
      context,
      expenditureController,
      assetsController,
    );
    if (mounted) {
      final String message;
      switch (importResult) {
        case ImportResult.success:
          message = l10n.importSuccess;
          break;
        case ImportResult.cancelled:
          message = l10n.importCancelled;
          break;
        case ImportResult.noPassword:
          message = l10n.importNoPassword;
          break;
        case ImportResult.wrongPassword:
          message = l10n.importWrongPassword;
          break;
        case ImportResult.failed:
          message = l10n.importFailed;
          break;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );
  }

  void _onCurrencyChanged(
    BuildContext context,
    String newCode,
    String oldCode,
    SettingsController settingsController,
    ExpenditureController expenditureController,
    AssetsController assetsController,
    AppLocalizations l10n,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.changeCurrency),
        content: Text(l10n.confirmCurrencyConversion(oldCode, newCode)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          TextButton(
            child: Text(l10n.proceed),
            onPressed: () async {
              Navigator.of(ctx).pop();
              _showLoadingDialog();
              try {
                await settingsController.updatePrimaryCurrency(
                  expenditureController,
                  assetsController,
                  newCode,
                  (from, to) =>
                      expenditureController.getBestExchangeRate(from, to),
                );
                if (mounted) Navigator.of(context).pop();
              } catch (e) {
                if (mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.exchangeRateError)),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _showResetConfirmationDialog(BuildContext context, Settings settings) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmReset),
        content: Text(
          l10n.confirmDeleteEverything,
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            child: Text(l10n.cancel),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.reset),
            onPressed: () {
              Navigator.of(ctx).pop();
              Provider.of<ExpenditureController>(
                context,
                listen: false,
              ).resetAllData(settings);
            },
          ),
        ],
      ),
    );
  }

  void _showAddCustomRateDialog(BuildContext context, AppLocalizations l10n) {
    final settingsController = Provider.of<SettingsController>(
      context,
      listen: false,
    );
    String fromCurrency = 'JPY';
    String toCurrency = 'VND';
    final rateController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final supportedCurrencies = [
      'JPY',
      'USD',
      'EUR',
      'CNY',
      'RUB',
      'VND',
      'AUD',
      'KRW',
      'THB',
      'PHP',
      'MYR',
    ];
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.addCustomRate),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButton<String>(
                        value: fromCurrency,
                        isExpanded: true,
                        items: supportedCurrencies
                            .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setDialogState(() => fromCurrency = val!),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Icon(Icons.arrow_forward),
                    ),
                    Expanded(
                      child: DropdownButton<String>(
                        value: toCurrency,
                        isExpanded: true,
                        items: supportedCurrencies
                            .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setDialogState(() => toCurrency = val!),
                      ),
                    ),
                  ],
                ),
                TextFormField(
                  controller: rateController,
                  decoration: InputDecoration(labelText: l10n.exchangeRate),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*')),
                  ],
                  validator: (v) =>
                      v == null || v.isEmpty ? l10n.validNumber : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.cancel),
            ),
            TextButton(
              child: Text(l10n.add),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final rate = double.tryParse(rateController.text);
                  if (rate != null && fromCurrency != toCurrency) {
                    settingsController.addOrUpdateCustomRate(
                      fromCurrency,
                      toCurrency,
                      rate,
                    );
                    Navigator.of(ctx).pop();
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCurrencyIcon(String currencyCode) {
    switch (currencyCode) {
      case 'JPY':
        return Icons.currency_yen;
      case 'USD':
        return Icons.attach_money;
      case 'EUR':
        return Icons.euro_symbol;
      case 'GBP':
        return Icons.currency_pound;
      case 'CNY':
        return Icons.currency_yuan;
      case 'RUB':
        return Icons.currency_ruble;
      case 'INR':
        return Icons.currency_rupee;
      default:
        return Icons.attach_money;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settingsAppBar = SettingsAppBar(l10n: l10n);
    final double appBarHeight = settingsAppBar.preferredSize.height;
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double totalTopOffset = appBarHeight + statusBarHeight;

    return BackGround(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: settingsAppBar,
        body: Consumer<SettingsController>(
          builder: (context, controller, child) {
            final settings = controller.settings;
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(8, totalTopOffset + 15, 8, 90),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      GlassCardContainer(
                        padding: EdgeInsets.zero,
                        margin: const EdgeInsets.only(bottom: 15),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SectionHeader(title: l10n.general),
                            _buildLanguageSetting(controller, l10n),
                            ListTile(
                              leading: const Icon(Icons.person_pin_outlined),
                              title: Text(l10n.financialContextTitle),
                              subtitle: Text(l10n.financialContextSubTitle),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const EditUserContextPage(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      GlassCardContainer(
                        padding: EdgeInsets.zero,
                        margin: const EdgeInsets.only(bottom: 15),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SectionHeader(title: l10n.reminders),
                            _buildReminderSettings(l10n),
                          ],
                        ),
                      ),
                      GlassCardContainer(
                        padding: EdgeInsets.zero,
                        margin: const EdgeInsets.only(bottom: 15),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SectionHeader(title: l10n.currency),
                            _buildCurrencySetting(controller, l10n),
                            _buildCustomRateSetting(controller, l10n),
                          ],
                        ),
                      ),
                      GlassCardContainer(
                        padding: EdgeInsets.zero,
                        margin: const EdgeInsets.only(bottom: 15),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SectionHeader(title: l10n.security),
                            _buildSecuritySettings(l10n),
                          ],
                        ),
                      ),
                      GlassCardContainer(
                        padding: EdgeInsets.zero,
                        margin: const EdgeInsets.only(bottom: 15),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SectionHeader(title: l10n.display),
                            _buildListGroupingSetting(controller, l10n),
                            ListTile(
                              leading: const Icon(Icons.list_alt),
                              title: Text(l10n.paginationLimit),
                              trailing: DropdownButton<int>(
                                value: settings.paginationLimit,
                                items: [25, 50, 100, 200]
                                    .map(
                                      (limit) => DropdownMenuItem(
                                        value: limit,
                                        child: Text('$limit'),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value != null)
                                    controller.updatePaginationLimit(value);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      GlassCardContainer(
                        padding: EdgeInsets.zero,
                        margin: const EdgeInsets.only(bottom: 15),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SectionHeader(title: l10n.dataManagement),
                            _buildDataManagementSettings(controller, l10n),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildDangerZone(settings, l10n),
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLanguageSetting(
    SettingsController controller,
    AppLocalizations l10n,
  ) => ListTile(
    leading: const Icon(Icons.language),
    title: Text(l10n.language),
    subtitle: Text(
      controller.settings.languageCode == null
          ? l10n.systemDefault
          : l10n.languageName(controller.settings.languageCode!),
    ),
    onTap: () => showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.language),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String?>(
              title: Text(l10n.systemDefault),
              value: null,
              groupValue: controller.settings.languageCode,
              onChanged: (val) {
                controller.updateLanguage(val);
                Navigator.of(ctx).pop();
              },
            ),
            ...AppLocalizations.supportedLocales.map(
              (locale) => RadioListTile<String?>(
                title: Text(l10n.languageName(locale.languageCode)),
                value: locale.languageCode,
                groupValue: controller.settings.languageCode,
                onChanged: (val) {
                  controller.updateLanguage(val);
                  Navigator.of(ctx).pop();
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildCurrencySetting(
    SettingsController controller,
    AppLocalizations l10n,
  ) {
    const supportedCurrencies = [
      'JPY',
      'USD',
      'EUR',
      'CNY',
      'RUB',
      'VND',
      'AUD',
      'KRW',
      'THB',
      'PHP',
      'MYR',
    ];
    final expenditureController = Provider.of<ExpenditureController>(
      context,
      listen: false,
    );
    final assetsController = Provider.of<AssetsController>(
      context,
      listen: false,
    );
    return ListTile(
      leading: Icon(_getCurrencyIcon(controller.settings.primaryCurrencyCode)),
      title: Text(l10n.primaryCurrency),
      subtitle: Text(
        l10n.currencyName(controller.settings.primaryCurrencyCode),
      ),
      onTap: () {
        final oldCode = controller.settings.primaryCurrencyCode;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.primaryCurrency),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: supportedCurrencies
                    .map(
                      (code) => RadioListTile<String>(
                        title: Text(l10n.currencyName(code)),
                        value: code,
                        groupValue: oldCode,
                        onChanged: (newCode) {
                          Navigator.of(ctx).pop();
                          if (newCode != null && newCode != oldCode) {
                            _onCurrencyChanged(
                              context,
                              newCode,
                              oldCode,
                              controller,
                              expenditureController,
                              assetsController,
                              l10n,
                            );
                          }
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReminderSettings(AppLocalizations l10n) {
    return Selector<SettingsController, bool>(
      selector: (_, controller) => controller.settings.remindersEnabled,
      builder: (context, remindersEnabledFromController, child) {
        final settingsController = context.read<SettingsController>();
        final bool isSwitchOn =
            _areRemindersEnabledByPermission && remindersEnabledFromController;
        return SwitchListTile(
          secondary: Icon(
            isSwitchOn
                ? Icons.notifications_active
                : Icons.notifications_off_outlined,
          ),
          title: Text(l10n.enableReminders),
          subtitle: Text(l10n.enableRemindersSubtitle),
          value: isSwitchOn,
          onChanged: (newValue) =>
              _onReminderSwitchChanged(newValue, settingsController),
        );
      },
    );
  }

  Widget _buildListGroupingSetting(
    SettingsController controller,
    AppLocalizations l10n,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      RadioListTile<DividerType>(
        title: Text(l10n.calendarMonth),
        subtitle: Text(l10n.msgCalendarMonth),
        value: DividerType.monthly,
        groupValue: controller.settings.dividerType,
        onChanged: (value) => controller.updateDividerType(value!),
      ),
      RadioListTile<DividerType>(
        title: Text(l10n.paydayCycle),
        subtitle: Text(l10n.msgPaydayCycle),
        value: DividerType.paydayCycle,
        groupValue: controller.settings.dividerType,
        onChanged: (value) => controller.updateDividerType(value!),
      ),
      if (controller.settings.dividerType == DividerType.paydayCycle)
        Padding(
          padding: const EdgeInsets.fromLTRB(72, 0, 16, 16),
          child: DropdownButtonFormField<int>(
            value: controller.settings.paydayStartDay,
            decoration: InputDecoration(labelText: l10n.cycleStartDate),
            items: List.generate(28, (i) => i + 1)
                .map(
                  (day) => DropdownMenuItem(
                    value: day,
                    child: Text(l10n.dayOfMonthLabel(day)),
                  ),
                )
                .toList(),
            onChanged: (value) => controller.updatePaydayStartDay(value!),
          ),
        ),
      RadioListTile<DividerType>(
        title: Text(l10n.fixedInterval),
        subtitle: Text(l10n.msgFixedInterval),
        value: DividerType.fixedInterval,
        groupValue: controller.settings.dividerType,
        onChanged: (value) {
          if (controller.settings.fixedIntervalDays <= 0)
            controller.updateFixedIntervalDays(7);
          controller.updateDividerType(value!);
        },
      ),
      if (controller.settings.dividerType == DividerType.fixedInterval)
        FixedIntervalSettings(controller: controller),
    ],
  );

  Widget _buildDangerZone(Settings settings, AppLocalizations l10n) =>
      GlassCard(
        margin: const EdgeInsets.symmetric(horizontal: 8.0),
        color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.5),
        onTap: () => _showResetConfirmationDialog(context, settings),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12.0),
          leading: Icon(
            Icons.warning_amber_rounded,
            color: Theme.of(context).colorScheme.error,
          ),
          title: Text(
            l10n.resetAllData,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onErrorContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            l10n.resetApp,
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onErrorContainer.withOpacity(0.8),
            ),
          ),
        ),
      );

  Widget _buildSecuritySettings(AppLocalizations l10n) {
    final secureStorage = SecureStorageService();
    return FutureBuilder<String?>(
      future: secureStorage.getPin(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const ListTile(title: Text("..."));
        final bool isPinSet = snapshot.hasData && snapshot.data != null;
        return SwitchListTile(
          secondary: Icon(
            isPinSet ? Icons.lock_person_rounded : Icons.lock_open_rounded,
          ),
          title: Text(l10n.pinLock),
          subtitle: Text(isPinSet ? l10n.pinIsEnabled : l10n.pinIsDisabled),
          value: isPinSet,
          onChanged: (bool value) async {
            if (value) {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const CreatePinPage()));
            } else {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(l10n.disablePin),
                  content: Text(l10n.disablePinMessage),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text(l10n.cancel),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: Text(
                        l10n.disable,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
              if (confirm == true && mounted) {
                _showLoadingDialog();
                await DatabaseService().migrateToUnencrypted();
                await secureStorage.deletePin();
                Phoenix.rebirth(context);
              }
            }
          },
        );
      },
    );
  }

  Widget _buildCustomRateSetting(
    SettingsController controller,
    AppLocalizations l10n,
  ) => ExpansionTile(
    leading: const Icon(Icons.rule_folder_outlined),
    title: Text(l10n.customExchangeRates),
    childrenPadding: const EdgeInsets.symmetric(horizontal: 16),
    children: [
      ...controller.customRates.map(
        (rate) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(rate.conversionPair.replaceAll('_', ' → ')),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(rate.rate.toString()),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.grey),
                  onPressed: () =>
                      controller.deleteCustomRate(rate.conversionPair),
                ),
              ],
            ),
          ],
        ),
      ),
      const Divider(),
      ListTile(
        title: Text(l10n.addCustomRate),
        leading: const Icon(Icons.add),
        contentPadding: EdgeInsets.zero,
        onTap: () => _showAddCustomRateDialog(context, l10n),
      ),
    ],
  );

  Widget _buildDataManagementSettings(
    SettingsController controller,
    AppLocalizations l10n,
  ) => Column(
    children: [
      ListTile(
        leading: const Icon(Icons.upload_file),
        title: Text(l10n.exportData),
        subtitle: Text(l10n.exportDataSubtitle),
        onTap: () => _handleExport(context, controller),
      ),
      ListTile(
        leading: const Icon(Icons.download_for_offline),
        title: Text(l10n.importData),
        subtitle: Text(l10n.importDataSubtitle),
        onTap: () => _handleImport(context, controller),
      ),
    ],
  );
}

class FixedIntervalSettings extends StatefulWidget {
  final SettingsController controller;
  const FixedIntervalSettings({super.key, required this.controller});
  @override
  State<FixedIntervalSettings> createState() => _FixedIntervalSettingsState();
}

class _FixedIntervalSettingsState extends State<FixedIntervalSettings> {
  static const int customIntervalValue = 0;
  final List<int> presetIntervals = [7, 14, 15, 30];
  late int selectedValue;
  late TextEditingController _customDaysController;

  @override
  void initState() {
    super.initState();
    final current = widget.controller.settings.fixedIntervalDays;
    selectedValue = presetIntervals.contains(current)
        ? current
        : customIntervalValue;
    _customDaysController = TextEditingController(
      text: isCustom(current) ? current.toString() : '',
    );
  }

  bool isCustom(int value) => !presetIntervals.contains(value);

  @override
  void didUpdateWidget(covariant FixedIntervalSettings oldWidget) {
    super.didUpdateWidget(oldWidget);
    final current = widget.controller.settings.fixedIntervalDays;
    final newSelectedValue = presetIntervals.contains(current)
        ? current
        : customIntervalValue;
    if (selectedValue != newSelectedValue) selectedValue = newSelectedValue;
  }

  @override
  void dispose() {
    _customDaysController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    bool showCustomField = selectedValue == customIntervalValue;
    return Padding(
      padding: const EdgeInsets.fromLTRB(72, 0, 16, 16),
      child: Column(
        children: [
          DropdownButtonFormField<int>(
            value: selectedValue,
            decoration: InputDecoration(labelText: l10n.interval),
            items: [
              ...presetIntervals.map(
                (day) => DropdownMenuItem(
                  value: day,
                  child: Text(l10n.daysUnit(day)),
                ),
              ),
              DropdownMenuItem(
                value: customIntervalValue,
                child: Text(l10n.custom),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  selectedValue = value;
                  if (value != customIntervalValue)
                    widget.controller.updateFixedIntervalDays(value);
                });
              }
            },
          ),
          if (showCustomField)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: TextFormField(
                controller: _customDaysController,
                decoration: InputDecoration(
                  labelText: l10n.customDays,
                  hintText: l10n.enterNumOfDays,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: false,
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (value) {
                  int days = int.tryParse(value) ?? 0;
                  if (days > 0 && days <= 180)
                    widget.controller.updateFixedIntervalDays(days);
                },
              ),
            ),
        ],
      ),
    );
  }
}
