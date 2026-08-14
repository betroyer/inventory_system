import 'package:drift/drift.dart';

import '../database/daos/products_dao.dart';
import '../database/database.dart';
import '../shared/models/enums.dart';
import 'notification_service.dart';
import 'settings_service.dart';

class StockAlertService {
  StockAlertService({
    required this.productsDao,
    required this.settingsService,
    required this.notificationService,
  });

  final ProductsDao productsDao;
  final SettingsService settingsService;
  final NotificationService notificationService;

  Future<void> checkAllProducts() async {
    if (settingsService.lowStockAlerts) {
      final lowStock = await productsDao.getLowStockProducts();
      for (final product in lowStock) {
        await _createAlertIfNeeded(
          product: product,
          type: AppNotificationType.lowStock,
          title: 'Low Stock Alert',
          message:
              '${product.name} has only ${product.quantity} piece${product.quantity == 1 ? '' : 's'} remaining.',
        );
      }
    }

    if (settingsService.outOfStockAlerts) {
      final outOfStock = await productsDao.getOutOfStockProducts();
      for (final product in outOfStock) {
        await _createAlertIfNeeded(
          product: product,
          type: AppNotificationType.outOfStock,
          title: 'Out of Stock',
          message: '${product.name} is out of stock.',
        );
      }
    }

    if (settingsService.expirationAlerts) {
      final expiring = await productsDao.getExpiringSoonProducts(
        settingsService.expirationWarningDays,
      );
      for (final product in expiring) {
        await _createAlertIfNeeded(
          product: product,
          type: AppNotificationType.expiration,
          title: 'Expiring Soon',
          message: '${product.name} is expiring soon.',
        );
      }

      final expired = await productsDao.getExpiredProducts();
      for (final product in expired) {
        await _createAlertIfNeeded(
          product: product,
          type: AppNotificationType.expiration,
          title: 'Product Expired',
          message: '${product.name} has expired.',
        );
      }
    }
  }

  Future<void> checkProduct(Product product) async {
    if (product.quantity <= 0 && settingsService.outOfStockAlerts) {
      await _createAlertIfNeeded(
        product: product,
        type: AppNotificationType.outOfStock,
        title: 'Out of Stock',
        message: '${product.name} is out of stock.',
      );
    } else if (product.quantity <= product.minimumStock &&
        settingsService.lowStockAlerts) {
      await _createAlertIfNeeded(
        product: product,
        type: AppNotificationType.lowStock,
        title: 'Low Stock Alert',
        message:
            '${product.name} has only ${product.quantity} piece${product.quantity == 1 ? '' : 's'} remaining.',
      );
    }
  }

  Future<void> _createAlertIfNeeded({
    required Product product,
    required AppNotificationType type,
    required String title,
    required String message,
  }) async {
    final exists = await productsDao.notificationExistsForProduct(
      product.id,
      type.value,
    );
    if (exists) return;

    await productsDao.insertNotification(
      AppNotificationsCompanion.insert(
        type: type.value,
        title: title,
        message: message,
        productId: Value(product.id),
      ),
    );

    await notificationService.showLocalNotification(
      id: product.id + type.index * 10000,
      title: title,
      body: message,
    );
  }
}
