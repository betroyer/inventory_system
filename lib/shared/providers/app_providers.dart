import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../database/database.dart';
import '../../services/backup_service.dart';
import '../../services/notification_service.dart';
import '../../services/settings_service.dart';
import '../../services/stock_alert_service.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final productsDaoProvider = Provider((ref) {
  return ref.watch(databaseProvider).productsDao;
});

final salesDaoProvider = Provider((ref) {
  return ref.watch(databaseProvider).salesDao;
});

final expensesDaoProvider = Provider((ref) {
  return ref.watch(databaseProvider).expensesDao;
});

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Override in main.dart');
});

final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService(ref.watch(sharedPreferencesProvider));
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref.watch(settingsServiceProvider));
});

final stockAlertServiceProvider = Provider<StockAlertService>((ref) {
  return StockAlertService(
    productsDao: ref.watch(productsDaoProvider),
    settingsService: ref.watch(settingsServiceProvider),
    notificationService: ref.watch(notificationServiceProvider),
  );
});

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(
    database: ref.watch(databaseProvider),
    settingsService: ref.watch(settingsServiceProvider),
  );
});

final productsProvider = StreamProvider<List<Product>>((ref) {
  return ref.watch(productsDaoProvider).watchAllProducts();
});

final categoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(productsDaoProvider).watchCategories();
});

final unreadNotificationCountProvider = StreamProvider<int>((ref) {
  return ref.watch(productsDaoProvider).watchUnreadNotificationCount();
});

final notificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  return ref.watch(productsDaoProvider).watchActiveNotifications();
});

final recentStockMovementsProvider =
    StreamProvider<List<StockMovement>>((ref) {
  return ref.watch(productsDaoProvider).watchRecentStockMovements();
});

final salesProvider = StreamProvider<List<Sale>>((ref) {
  return ref.watch(salesDaoProvider).watchAllSales();
});

final expensesProvider = StreamProvider<List<Expense>>((ref) {
  return ref.watch(expensesDaoProvider).watchAllExpenses();
});

final dashboardSummaryProvider = FutureProvider<DashboardSummary>((ref) async {
  final salesDao = ref.watch(salesDaoProvider);
  final expensesDao = ref.watch(expensesDaoProvider);
  final productsDao = ref.watch(productsDaoProvider);
  final settings = ref.watch(settingsServiceProvider);

  final now = DateTime.now();
  final dailySales = await salesDao.getDailySummary(now);
  final dailyExpenses = await expensesDao.getDailyExpenses(now);
  final products = await productsDao.watchAllProducts().first;
  final lowStock = await productsDao.getLowStockProducts();
  final outOfStock = await productsDao.getOutOfStockProducts();
  final expiringSoon = await productsDao.getExpiringSoonProducts(
    settings.expirationWarningDays,
  );

  return DashboardSummary(
    todaySales: dailySales.totalSales,
    todayProfit: dailySales.totalProfit - dailyExpenses,
    totalProducts: products.length,
    lowStockCount: lowStock.length,
    outOfStockCount: outOfStock.length,
    expiringSoonCount: expiringSoon.length,
    transactionCount: dailySales.transactionCount,
    products: products,
    warningDays: settings.expirationWarningDays,
  );
});

class DashboardSummary {
  const DashboardSummary({
    required this.todaySales,
    required this.todayProfit,
    required this.totalProducts,
    required this.lowStockCount,
    required this.outOfStockCount,
    required this.expiringSoonCount,
    required this.transactionCount,
    required this.products,
    required this.warningDays,
  });

  final double todaySales;
  final double todayProfit;
  final int totalProducts;
  final int lowStockCount;
  final int outOfStockCount;
  final int expiringSoonCount;
  final int transactionCount;
  final List<Product> products;
  final int warningDays;
}
