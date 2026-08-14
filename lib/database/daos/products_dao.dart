import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/tables.dart';

part 'products_dao.g.dart';

@DriftAccessor(tables: [Products, Categories, StockMovements, AppNotifications])
class ProductsDao extends DatabaseAccessor<AppDatabase>
    with _$ProductsDaoMixin {
  ProductsDao(super.db);

  Stream<List<Product>> watchAllProducts() {
    return (select(products)..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  Stream<List<Product>> watchProductsByCategory(int? categoryId) {
    final query = select(products)
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);
    if (categoryId != null) {
      query.where((t) => t.categoryId.equals(categoryId));
    }
    return query.watch();
  }

  Future<Product?> getProduct(int id) =>
      (select(products)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<Product>> searchProducts(String query) {
    return (select(products)
          ..where((t) => t.name.like('%$query%'))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  Future<int> insertProduct(ProductsCompanion product) =>
      into(products).insert(product);

  Future<void> updateProductById(int id, ProductsCompanion companion) {
    return (update(products)..where((t) => t.id.equals(id))).write(companion);
  }

  Future<int> deleteProduct(int id) =>
      (delete(products)..where((t) => t.id.equals(id))).go();

  Future<void> updateProductQuantity(int id, int newQuantity) {
    return (update(products)..where((t) => t.id.equals(id))).write(
      ProductsCompanion(
        quantity: Value(newQuantity),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Stream<List<Category>> watchCategories() {
    return (select(categories)..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  Future<List<Category>> getAllCategories() =>
      (select(categories)..orderBy([(t) => OrderingTerm.asc(t.name)])).get();

  Future<int> insertCategory(CategoriesCompanion category) =>
      into(categories).insert(category);

  Future<int> insertStockMovement(StockMovementsCompanion movement) =>
      into(stockMovements).insert(movement);

  Stream<List<StockMovement>> watchStockMovementsForProduct(int productId) {
    return (select(stockMovements)
          ..where((t) => t.productId.equals(productId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Stream<List<StockMovement>> watchRecentStockMovements({int limit = 20}) {
    return (select(stockMovements)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(limit))
        .watch();
  }

  Future<List<Product>> getLowStockProducts() {
    return customSelect(
      '''
      SELECT p.* FROM products p
      WHERE p.quantity > 0 AND p.quantity <= p.minimum_stock
      ORDER BY p.quantity ASC
      ''',
      readsFrom: {products},
    ).map((row) => products.map(row.data)).get();
  }

  Future<List<Product>> getOutOfStockProducts() {
    return (select(products)
          ..where((t) => t.quantity.isSmallerOrEqualValue(0))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  Future<List<Product>> getExpiringSoonProducts(int warningDays) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final limit = today.add(Duration(days: warningDays));
    return (select(products)
          ..where((t) =>
              t.expirationDate.isNotNull() &
              t.expirationDate.isBiggerOrEqualValue(today) &
              t.expirationDate.isSmallerOrEqualValue(limit))
          ..orderBy([(t) => OrderingTerm.asc(t.expirationDate)]))
        .get();
  }

  Future<List<Product>> getExpiredProducts() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return (select(products)
          ..where((t) =>
              t.expirationDate.isNotNull() &
              t.expirationDate.isSmallerThanValue(today))
          ..orderBy([(t) => OrderingTerm.asc(t.expirationDate)]))
        .get();
  }

  Stream<int> watchUnreadNotificationCount() {
    final count = appNotifications.id.count(
      filter: appNotifications.isRead.equals(false) &
          appNotifications.isDismissed.equals(false),
    );
    return (selectOnly(appNotifications)..addColumns([count]))
        .map((row) => row.read(count) ?? 0)
        .watchSingle();
  }

  Stream<List<AppNotification>> watchActiveNotifications() {
    return (select(appNotifications)
          ..where((t) => t.isDismissed.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Future<int> insertNotification(AppNotificationsCompanion notification) =>
      into(appNotifications).insert(notification);

  Future<bool> notificationExistsForProduct(
    int productId,
    String type,
  ) async {
    final result = await (select(appNotifications)
          ..where((t) =>
              t.productId.equals(productId) &
              t.type.equals(type) &
              t.isDismissed.equals(false)))
        .getSingleOrNull();
    return result != null;
  }

  Future<void> markNotificationRead(int id) {
    return (update(appNotifications)..where((t) => t.id.equals(id))).write(
      const AppNotificationsCompanion(isRead: Value(true)),
    );
  }

  Future<void> dismissNotification(int id) {
    return (update(appNotifications)..where((t) => t.id.equals(id))).write(
      const AppNotificationsCompanion(isDismissed: Value(true)),
    );
  }
}
