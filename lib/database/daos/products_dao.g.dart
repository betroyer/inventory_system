// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'products_dao.dart';

// ignore_for_file: type=lint
mixin _$ProductsDaoMixin on DatabaseAccessor<AppDatabase> {
  $ProductsTable get products => attachedDatabase.products;
  $CategoriesTable get categories => attachedDatabase.categories;
  $StockMovementsTable get stockMovements => attachedDatabase.stockMovements;
  $AppNotificationsTable get appNotifications =>
      attachedDatabase.appNotifications;
  ProductsDaoManager get managers => ProductsDaoManager(this);
}

class ProductsDaoManager {
  final _$ProductsDaoMixin _db;
  ProductsDaoManager(this._db);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db.attachedDatabase, _db.products);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$StockMovementsTableTableManager get stockMovements =>
      $$StockMovementsTableTableManager(
        _db.attachedDatabase,
        _db.stockMovements,
      );
  $$AppNotificationsTableTableManager get appNotifications =>
      $$AppNotificationsTableTableManager(
        _db.attachedDatabase,
        _db.appNotifications,
      );
}
