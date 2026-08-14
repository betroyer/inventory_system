import 'dart:io';

import 'package:drift/drift.dart' hide Column;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_constants.dart';
import '../../database/database.dart';
import '../../shared/providers/app_providers.dart';
import 'pin_setup_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _storeNameController;
  late final TextEditingController _ownerNameController;
  late final TextEditingController _contactController;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsServiceProvider);
    _storeNameController = TextEditingController(text: settings.storeName);
    _ownerNameController = TextEditingController(text: settings.ownerName);
    _contactController = TextEditingController(text: settings.contactInfo);
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _ownerNameController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _saveStoreInfo() async {
    final settings = ref.read(settingsServiceProvider);
    await settings.setStoreName(_storeNameController.text.trim());
    await settings.setOwnerName(_ownerNameController.text.trim());
    await settings.setContactInfo(_contactController.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Store info saved.')),
      );
    }
  }

  Future<void> _pickStorePhoto() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file != null) {
      await ref.read(settingsServiceProvider).setStorePhotoPath(file.path);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Store Information',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (settings.storePhotoPath != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                File(settings.storePhotoPath!),
                height: 100,
                width: 100,
                fit: BoxFit.cover,
              ),
            ),
          TextButton(
            onPressed: _pickStorePhoto,
            child: const Text('Change Store Photo'),
          ),
          TextField(
            controller: _storeNameController,
            decoration: const InputDecoration(labelText: 'Store Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ownerNameController,
            decoration: const InputDecoration(labelText: 'Owner Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contactController,
            decoration: const InputDecoration(labelText: 'Contact Info'),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _saveStoreInfo, child: const Text('Save')),
          const Divider(height: 32),
          Text('Appearance',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'light', label: Text('Light')),
              ButtonSegment(value: 'dark', label: Text('Dark')),
              ButtonSegment(value: 'system', label: Text('System')),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (value) async {
              await settings.setThemeMode(value.first);
              ref.invalidate(settingsServiceProvider);
            },
          ),
          const Divider(height: 32),
          Text('Notifications',
              style: Theme.of(context).textTheme.titleMedium),
          SwitchListTile(
            title: const Text('Low Stock Alerts'),
            value: settings.lowStockAlerts,
            onChanged: (v) async {
              await settings.setLowStockAlerts(v);
              setState(() {});
            },
          ),
          SwitchListTile(
            title: const Text('Out of Stock Alerts'),
            value: settings.outOfStockAlerts,
            onChanged: (v) async {
              await settings.setOutOfStockAlerts(v);
              setState(() {});
            },
          ),
          SwitchListTile(
            title: const Text('Expiration Alerts'),
            value: settings.expirationAlerts,
            onChanged: (v) async {
              await settings.setExpirationAlerts(v);
              setState(() {});
            },
          ),
          SwitchListTile(
            title: const Text('Phone Notifications'),
            value: settings.phoneNotifications,
            onChanged: (v) async {
              await settings.setPhoneNotifications(v);
              setState(() {});
            },
          ),
          ListTile(
            title: const Text('Expiration Warning Period'),
            subtitle: Text('${settings.expirationWarningDays} days'),
            trailing: DropdownButton<int>(
              value: settings.expirationWarningDays,
              items: const [3, 7, 14, 30]
                  .map((d) => DropdownMenuItem(value: d, child: Text('$d days')))
                  .toList(),
              onChanged: (value) async {
                if (value != null) {
                  await settings.setExpirationWarningDays(value);
                  setState(() {});
                }
              },
            ),
          ),
          const Divider(height: 32),
          Text('Security', style: Theme.of(context).textTheme.titleMedium),
          ListTile(
            title: Text(settings.pinCode != null ? 'Change PIN' : 'Set PIN'),
            trailing: const Icon(Icons.lock_outline),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PinSetupScreen()),
            ),
          ),
          SwitchListTile(
            title: const Text('Biometric Unlock'),
            value: settings.biometricEnabled,
            onChanged: settings.pinCode != null
                ? (v) async {
                    await settings.setBiometricEnabled(v);
                    setState(() {});
                  }
                : null,
          ),
          const Divider(height: 32),
          Text('Data', style: Theme.of(context).textTheme.titleMedium),
          ListTile(
            title: const Text('Export Backup'),
            onTap: () async {
              await ref.read(backupServiceProvider).shareBackup();
            },
          ),
          ListTile(
            title: const Text('Restore Backup'),
            onTap: () async {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['json'],
              );
              if (result != null && result.files.single.path != null) {
                await ref
                    .read(backupServiceProvider)
                    .restoreBackup(File(result.files.single.path!));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Backup restored.')),
                  );
                }
              }
            },
          ),
          ListTile(
            title: const Text('Export Products CSV'),
            onTap: () async {
              await ref.read(backupServiceProvider).exportProductsCsv();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('CSV exported to documents.')),
                );
              }
            },
          ),
          const Divider(height: 32),
          Text('Categories', style: Theme.of(context).textTheme.titleMedium),
          ...AppConstants.defaultCategories.map(
            (name) => ListTile(
              title: Text(name),
              trailing: IconButton(
                icon: const Icon(Icons.add),
                onPressed: () async {
                  try {
                    await ref.read(productsDaoProvider).insertCategory(
                          CategoriesCompanion.insert(name: name),
                        );
                  } catch (_) {}
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}