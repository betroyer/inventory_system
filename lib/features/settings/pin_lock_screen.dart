import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../shared/providers/app_providers.dart';

class PinLockScreen extends ConsumerStatefulWidget {
  const PinLockScreen({super.key, required this.onUnlocked});

  final VoidCallback onUnlocked;

  @override
  ConsumerState<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends ConsumerState<PinLockScreen> {
  final _pinController = TextEditingController();
  final _localAuth = LocalAuthentication();
  String? _error;

  @override
  void initState() {
    super.initState();
    _tryBiometric();
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _tryBiometric() async {
    final settings = ref.read(settingsServiceProvider);
    if (!settings.biometricEnabled || settings.pinCode == null) return;

    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!canCheck) return;
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Unlock your store app',
        options: const AuthenticationOptions(biometricOnly: true),
      );
      if (authenticated && mounted) widget.onUnlocked();
    } catch (_) {}
  }

  void _verifyPin() {
    final settings = ref.read(settingsServiceProvider);
    if (_pinController.text.trim() == settings.pinCode) {
      widget.onUnlocked();
    } else {
      setState(() => _error = 'Incorrect PIN');
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsServiceProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 64),
              const SizedBox(height: 16),
              Text(
                settings.storeName,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text('Enter PIN to unlock'),
              const SizedBox(height: 24),
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  errorText: _error,
                  hintText: '••••',
                ),
                onSubmitted: (_) => _verifyPin(),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _verifyPin, child: const Text('Unlock')),
              if (settings.biometricEnabled) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _tryBiometric,
                  child: const Text('Use Biometrics'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
