import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  SettingsService(this._prefs);

  final SharedPreferences _prefs;

  static const _storeNameKey = 'store_name';
  static const _ownerNameKey = 'owner_name';
  static const _contactKey = 'contact_info';
  static const _storePhotoKey = 'store_photo_path';
  static const _themeModeKey = 'theme_mode';
  static const _pinKey = 'pin_code';
  static const _biometricKey = 'biometric_enabled';
  static const _lowStockAlertsKey = 'low_stock_alerts';
  static const _outOfStockAlertsKey = 'out_of_stock_alerts';
  static const _expirationAlertsKey = 'expiration_alerts';
  static const _phoneNotificationsKey = 'phone_notifications';
  static const _expirationDaysKey = 'expiration_warning_days';
  static const _isSetupCompleteKey = 'is_setup_complete';
  static const _monthlyTargetKey = 'monthly_sales_target';

  String get storeName => _prefs.getString(_storeNameKey) ?? 'My Sari-Sari Store';
  String get ownerName => _prefs.getString(_ownerNameKey) ?? '';
  String get contactInfo => _prefs.getString(_contactKey) ?? '';
  String? get storePhotoPath => _prefs.getString(_storePhotoKey);
  String get themeMode => _prefs.getString(_themeModeKey) ?? 'system';
  String? get pinCode => _prefs.getString(_pinKey);
  bool get biometricEnabled => _prefs.getBool(_biometricKey) ?? false;
  bool get lowStockAlerts => _prefs.getBool(_lowStockAlertsKey) ?? true;
  bool get outOfStockAlerts => _prefs.getBool(_outOfStockAlertsKey) ?? true;
  bool get expirationAlerts => _prefs.getBool(_expirationAlertsKey) ?? true;
  bool get phoneNotifications => _prefs.getBool(_phoneNotificationsKey) ?? false;
  int get expirationWarningDays => _prefs.getInt(_expirationDaysKey) ?? 7;
  bool get isSetupComplete => _prefs.getBool(_isSetupCompleteKey) ?? false;
  double get monthlySalesTarget =>
      _prefs.getDouble(_monthlyTargetKey) ?? 50000;

  Future<void> setStoreName(String value) => _prefs.setString(_storeNameKey, value);
  Future<void> setOwnerName(String value) => _prefs.setString(_ownerNameKey, value);
  Future<void> setContactInfo(String value) => _prefs.setString(_contactKey, value);
  Future<void> setStorePhotoPath(String? value) {
    if (value == null) return _prefs.remove(_storePhotoKey);
    return _prefs.setString(_storePhotoKey, value);
  }

  Future<void> setThemeMode(String value) => _prefs.setString(_themeModeKey, value);
  Future<void> setPinCode(String? value) {
    if (value == null) return _prefs.remove(_pinKey);
    return _prefs.setString(_pinKey, value);
  }

  Future<void> setBiometricEnabled(bool value) =>
      _prefs.setBool(_biometricKey, value);
  Future<void> setLowStockAlerts(bool value) =>
      _prefs.setBool(_lowStockAlertsKey, value);
  Future<void> setOutOfStockAlerts(bool value) =>
      _prefs.setBool(_outOfStockAlertsKey, value);
  Future<void> setExpirationAlerts(bool value) =>
      _prefs.setBool(_expirationAlertsKey, value);
  Future<void> setPhoneNotifications(bool value) =>
      _prefs.setBool(_phoneNotificationsKey, value);
  Future<void> setExpirationWarningDays(int value) =>
      _prefs.setInt(_expirationDaysKey, value);
  Future<void> setSetupComplete(bool value) =>
      _prefs.setBool(_isSetupCompleteKey, value);
  Future<void> setMonthlySalesTarget(double value) =>
      _prefs.setDouble(_monthlyTargetKey, value);

  Map<String, dynamic> toJson() => {
        'storeName': storeName,
        'ownerName': ownerName,
        'contactInfo': contactInfo,
        'storePhotoPath': storePhotoPath,
        'themeMode': themeMode,
        'lowStockAlerts': lowStockAlerts,
        'outOfStockAlerts': outOfStockAlerts,
        'expirationAlerts': expirationAlerts,
        'phoneNotifications': phoneNotifications,
        'expirationWarningDays': expirationWarningDays,
        'monthlySalesTarget': monthlySalesTarget,
      };

  Future<void> restoreFromJson(Map<String, dynamic> json) async {
    await setStoreName(json['storeName'] as String? ?? storeName);
    await setOwnerName(json['ownerName'] as String? ?? '');
    await setContactInfo(json['contactInfo'] as String? ?? '');
    if (json['storePhotoPath'] != null) {
      await setStorePhotoPath(json['storePhotoPath'] as String);
    }
    await setThemeMode(json['themeMode'] as String? ?? 'system');
    await setLowStockAlerts(json['lowStockAlerts'] as bool? ?? true);
    await setOutOfStockAlerts(json['outOfStockAlerts'] as bool? ?? true);
    await setExpirationAlerts(json['expirationAlerts'] as bool? ?? true);
    await setPhoneNotifications(json['phoneNotifications'] as bool? ?? false);
    await setExpirationWarningDays(json['expirationWarningDays'] as int? ?? 7);
    final target = json['monthlySalesTarget'];
    if (target is num) {
      await setMonthlySalesTarget(target.toDouble());
    }
  }
}
