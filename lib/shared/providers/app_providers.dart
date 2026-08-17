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

final stockMovementsForProductProvider =
    StreamProvider.family<List<StockMovement>, int>((ref, productId) {
  return ref
      .watch(productsDaoProvider)
      .watchStockMovementsForProduct(productId);
});

final salesProvider = StreamProvider<List<Sale>>((ref) {
  return ref.watch(salesDaoProvider).watchAllSales();
});

final expensesProvider = StreamProvider<List<Expense>>((ref) {
  return ref.watch(expensesDaoProvider).watchAllExpenses();
});

final dashboardSummaryProvider = FutureProvider<DashboardSummary>((ref) async {
  ref.watch(salesProvider);
  ref.watch(expensesProvider);
  ref.watch(productsProvider);
  ref.watch(categoriesProvider);

  final salesDao = ref.watch(salesDaoProvider);
  final expensesDao = ref.watch(expensesDaoProvider);
  final productsDao = ref.watch(productsDaoProvider);
  final settings = ref.watch(settingsServiceProvider);

  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final weekStart = todayStart.subtract(Duration(days: todayStart.weekday - 1));
  final prevWeekStart = weekStart.subtract(const Duration(days: 7));
  final monthStart = DateTime(now.year, now.month, 1);
  final prevMonthStart = DateTime(now.year, now.month - 1, 1);
  final sparkStart = todayStart.subtract(const Duration(days: 6));

  final dailySales = await salesDao.getDailySummary(now);
  final dailyExpenses = await expensesDao.getDailyExpenses(now);
  final products = await productsDao.watchAllProducts().first;
  final categories = await productsDao.getAllCategories();
  final lowStock = await productsDao.getLowStockProducts();
  final outOfStock = await productsDao.getOutOfStockProducts();
  final expiringSoon = await productsDao.getExpiringSoonProducts(
    settings.expirationWarningDays,
  );

  final week = await salesDao.getRangeTotals(
    weekStart,
    weekStart.add(const Duration(days: 7)),
  );
  final prevWeek = await salesDao.getRangeTotals(
    prevWeekStart,
    weekStart,
  );
  final month = await salesDao.getRangeTotals(
    monthStart,
    DateTime(now.year, now.month + 1, 1),
  );
  final prevMonth = await salesDao.getRangeTotals(
    prevMonthStart,
    monthStart,
  );
  final weekExpenses = await expensesDao.getTotalExpensesForDateRange(
    weekStart,
    weekStart.add(const Duration(days: 7)),
  );
  final prevWeekExpenses = await expensesDao.getTotalExpensesForDateRange(
    prevWeekStart,
    weekStart,
  );
  final sparkTrend = await salesDao.getSalesTrend(
    start: sparkStart,
    end: todayStart.add(const Duration(days: 1)),
  );

  final sparkline = List<double>.generate(7, (i) {
    final day = sparkStart.add(Duration(days: i));
    final match = sparkTrend.where(
      (p) =>
          p.date.year == day.year &&
          p.date.month == day.month &&
          p.date.day == day.day,
    );
    return match.isEmpty ? 0.0 : match.first.total;
  });

  final createdThisWeek =
      products.where((p) => p.createdAt.isAfter(weekStart)).length;
  final newCategoriesThisMonth =
      categories.where((c) => c.createdAt.isAfter(monthStart)).length;

  return DashboardSummary(
    todaySales: dailySales.totalSales,
    todayProfit: dailySales.totalProfit - dailyExpenses,
    weekProfit: week.totalProfit - weekExpenses,
    prevWeekProfit: prevWeek.totalProfit - prevWeekExpenses,
    totalProducts: products.length,
    categoryCount: categories.length,
    monthUnitsSold: month.unitsSold,
    prevMonthUnitsSold: prevMonth.unitsSold,
    monthIncome: month.totalSales,
    prevMonthIncome: prevMonth.totalSales,
    productGrowthBase: products.length - createdThisWeek,
    categoryGrowthBase: categories.length - newCategoriesThisMonth,
    sparkline: sparkline,
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
    required this.weekProfit,
    required this.prevWeekProfit,
    required this.totalProducts,
    required this.categoryCount,
    required this.monthUnitsSold,
    required this.prevMonthUnitsSold,
    required this.monthIncome,
    required this.prevMonthIncome,
    required this.productGrowthBase,
    required this.categoryGrowthBase,
    required this.sparkline,
    required this.lowStockCount,
    required this.outOfStockCount,
    required this.expiringSoonCount,
    required this.transactionCount,
    required this.products,
    required this.warningDays,
  });

  final double todaySales;
  final double todayProfit;
  final double weekProfit;
  final double prevWeekProfit;
  final int totalProducts;
  final int categoryCount;
  final double monthUnitsSold;
  final double prevMonthUnitsSold;
  final double monthIncome;
  final double prevMonthIncome;
  final int productGrowthBase;
  final int categoryGrowthBase;
  final List<double> sparkline;
  final int lowStockCount;
  final int outOfStockCount;
  final int expiringSoonCount;
  final int transactionCount;
  final List<Product> products;
  final int warningDays;
}
