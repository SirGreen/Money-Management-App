// import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:local_auth/local_auth.dart';
import 'package:test_app/app/services/database_service.dart';
import 'package:test_app/app/services/secure_storage_service.dart';
import 'package:test_app/app/views/helpers/glass_card.dart';
import 'package:test_app/app/views/helpers/gradient_background.dart';
import 'package:test_app/app/views/helpers/pin_input_widget.dart';
import 'package:test_app/l10n/app_localizations.dart';

class PinLockPage extends StatefulWidget {
  final VoidCallback onUnlock;
  const PinLockPage({super.key, required this.onUnlock});

  @override
  State<PinLockPage> createState() => _PinLockPageState();
}

class _PinLockPageState extends State<PinLockPage> {
  String _errorMessage = "";
  final LocalAuthentication _auth = LocalAuthentication();
  bool _canCheckBiometrics = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      if (mounted) {
        setState(() {
          _canCheckBiometrics = canCheck;
          if (_canCheckBiometrics) {
            _tryBiometricUnlock();
          }
        });
      }
    } catch (e) {
      print("Error checking biometrics: $e");
    }
  }

  Future<void> _tryBiometricUnlock() async {
    if (!_canCheckBiometrics) return;
    try {
      final l10n = AppLocalizations.of(context)!;
      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: l10n.authenticateToUnlock,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (didAuthenticate) {
        widget.onUnlock();
      }
    } catch (e) {
      print("Biometric authentication error: $e");
    }
  }

  Future<void> _verifyPin(String pin) async {
    final l10n = AppLocalizations.of(context)!;
    final storedPin = await SecureStorageService().getPin();
    if (pin == storedPin) {
      widget.onUnlock();
    } else {
      setState(() {
        _errorMessage = l10n.incorrectPin;
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _errorMessage = "");
      });
    }
  }

  void _showForgotPinDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.resetConfirmation),
        content: Text(l10n.resetWarningMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            icon: const Icon(Icons.warning_amber_rounded),
            label: Text(l10n.resetAndStartOver),
            onPressed: () async {
              await DatabaseService().deleteAllDataAndReset();
              if (mounted) {
                Phoenix.rebirth(context);
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // final double topPadding = MediaQuery.of(context).padding.top;

    return BackGround(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),
                GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_person_rounded,
                        size: 40,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        l10n.enterPin,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: _errorMessage.isNotEmpty ? 24 : 0,
                        child: _errorMessage.isNotEmpty
                            ? Text(
                                _errorMessage,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 16),
                      PinInputWidget(
                        onCompleted: _verifyPin,
                        onBiometric: _canCheckBiometrics ? _tryBiometricUnlock : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: _showForgotPinDialog,
                  child: Text(l10n.forgotPin),
                ),
                const Spacer(flex: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}