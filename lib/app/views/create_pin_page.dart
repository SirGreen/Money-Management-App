import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:test_app/app/services/database_service.dart';
import 'package:test_app/app/services/encryption_service.dart';
import 'package:test_app/app/services/secure_storage_service.dart';
import 'package:test_app/app/views/helpers/glass_card.dart';
import 'package:test_app/app/views/helpers/gradient_background.dart';
import 'package:test_app/app/views/helpers/gradient_title.dart';
import 'package:test_app/app/views/helpers/pin_input_widget.dart';
import 'package:test_app/l10n/app_localizations.dart';

class CreatePinAppBar extends StatelessWidget implements PreferredSizeWidget {
  final AppLocalizations l10n;

  const CreatePinAppBar({
    super.key,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: AppBar(
          title: GradientTitle(text: l10n.setupPin),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.white.withOpacity(0.2),
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
            side: BorderSide(color: Colors.white.withOpacity(0.3)),
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

enum PinSetupStep { create, confirm }

class CreatePinPage extends StatefulWidget {
  const CreatePinPage({super.key});

  @override
  State<CreatePinPage> createState() => _CreatePinPageState();
}

class _CreatePinPageState extends State<CreatePinPage> {
  PinSetupStep _currentStep = PinSetupStep.create;
  String _firstPin = "";
  String _errorMessage = "";
  bool _isSaving = false;

  void _onPinCreated(String pin) {
    setState(() {
      _firstPin = pin;
      _currentStep = PinSetupStep.confirm;
    });
  }

  Future<void> _onPinConfirmed(String pin) async {
    final l10n = AppLocalizations.of(context)!;
    if (pin == _firstPin) {
      setState(() => _isSaving = true);

      await SecureStorageService().savePin(pin);

      final encryptionKey = await EncryptionService.getEncryptionKey();
      final cipher = HiveAesCipher(encryptionKey);

      await DatabaseService().migrateToEncrypted(cipher);

      if (mounted) {
        Phoenix.rebirth(context);
      }
    } else {
      setState(() {
        _errorMessage = l10n.pinsDoNotMatch;
        _currentStep = PinSetupStep.create;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final createPinAppBar = CreatePinAppBar(l10n: l10n);
    final double appBarHeight = createPinAppBar.preferredSize.height;
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double totalTopOffset = appBarHeight + statusBarHeight;

    return BackGround(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: createPinAppBar,
        body: Padding(
          padding: EdgeInsets.only(top: totalTopOffset),
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height - totalTopOffset,
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: _isSaving
                      ? const CircularProgressIndicator()
                      : GlassCard(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _currentStep == PinSetupStep.create
                                    ? Icons.lock_outline
                                    : Icons.lock,
                                size: 40,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _currentStep == PinSetupStep.create
                                    ? l10n.enterNewPin
                                    : l10n.confirmNewPin,
                                style: Theme.of(context).textTheme.headlineSmall,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                height: _errorMessage.isNotEmpty ? 24 : 0,
                                child: _errorMessage.isNotEmpty
                                    ? Text(_errorMessage,
                                        style:
                                            const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
                                    : null,
                              ),
                              PinInputWidget(
                                key: ValueKey(_currentStep),
                                onCompleted: (pin) {
                                  if (_currentStep == PinSetupStep.create) {
                                    _onPinCreated(pin);
                                  } else {
                                    _onPinConfirmed(pin);
                                  }
                                },
                                isCreatePin: true,
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}