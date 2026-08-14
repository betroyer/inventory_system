import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../database/database.dart';
import '../../features/settings/pin_lock_screen.dart';
import '../../shared/providers/app_providers.dart';
import 'routes/main_shell.dart';
import 'theme/app_theme.dart';

class SariSariApp extends ConsumerStatefulWidget {
  const SariSariApp({super.key});

  @override
  ConsumerState<SariSariApp> createState() => _SariSariAppState();
}

class _SariSariAppState extends ConsumerState<SariSariApp> {
  bool _locked = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_initialize);
  }

  Future<void> _initialize() async {
    await ref.read(notificationServiceProvider).initialize();
    await ref.read(stockAlertServiceProvider).checkAllProducts();
    await _seedDefaultCategories();

    final pin = ref.read(settingsServiceProvider).pinCode;
    setState(() {
      _locked = pin != null;
      _initialized = true;
    });
  }

  Future<void> _seedDefaultCategories() async {
    final dao = ref.read(productsDaoProvider);
    final existing = await dao.getAllCategories();
    if (existing.isNotEmpty) return;

    for (final name in AppConstants.defaultCategories) {
      try {
        await dao.insertCategory(CategoriesCompanion.insert(name: name));
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsServiceProvider);
    final themeMode = switch (settings.themeMode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    if (!_initialized) {
      return MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return MaterialApp(
      title: settings.storeName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: _locked
          ? PinLockScreen(onUnlocked: () => setState(() => _locked = false))
          : const MainShell(),
    );
  }
}