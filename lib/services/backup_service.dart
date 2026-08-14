import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/database.dart';
import 'settings_service.dart';

class BackupService {
  BackupService({
    required this.database,
    required this.settingsService,
  });

  final AppDatabase database;
  final SettingsService settingsService;

  Future<File> exportBackup() async {
    final products = await database.select(database.products).get();
    final categories = await database.select(database.categories).get();
    final sales = await database.select(database.sales).get();
    final saleItems = await database.select(database.saleItems).get();
    final stockMovements = await database.select(database.stockMovements).get();
    final expenses = await database.select(database.expenses).get();
    final notifications =
        await database.select(database.appNotifications).get();

    final data = {
      'version': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'settings': settingsService.toJson(),
      'products': products.map(_productToJson).toList(),
      'categories': categories.map(_categoryToJson).toList(),
      'sales': sales.map(_saleToJson).toList(),
      'saleItems': saleItems.map(_saleItemToJson).toList(),
      'stockMovements': stockMovements.map(_movementToJson).toList(),
      'expenses': expenses.map(_expenseToJson).toList(),
      'notifications': notifications.map(_notificationToJson).toList(),
    };

    final dir = await getApplicationDocumentsDirectory();
    final file = File(
      p.join(
        dir.path,
        'sari_sari_backup_${DateTime.now().millisecondsSinceEpoch}.json',
      ),
    );
    await file.writeAsString(jsonEncode(data));
    return file;
  }

  Future<void> shareBackup() async {
    final file = await exportBackup();
    await Share.shareXFiles([XFile(file.path)], text: 'Sari-Sari Store Backup');
  }

  Future<void> restoreBackup(File file) async {
    final content = await file.readAsString();
    final data = jsonDecode(content) as Map<String, dynamic>;

    await database.transaction(() async {
      await database.delete(database.appNotifications).go();
      await database.delete(database.stockMovements).go();
      await database.delete(database.saleItems).go();
      await database.delete(database.sales).go();
      await database.delete(database.expenses).go();
      await database.delete(database.products).go();
      await database.delete(database.categories).go();

      for (final item in data['categories'] as List<dynamic>) {
        await database.into(database.categories).insert(
              CategoriesCompanion(
                id: item['id'] != null ? Value(item['id'] as int) : const Value.absent(),
                name: Value(item['name'] as String),
                createdAt: item['createdAt'] != null
                    ? Value(DateTime.parse(item['createdAt'] as String))
                    : const Value.absent(),
              ),
            );
      }

      for (final item in data['products'] as List<dynamic>) {
        await database.into(database.products).insert(
              ProductsCompanion(
                id: item['id'] != null ? Value(item['id'] as int) : const Value.absent(),
                name: Value(item['name'] as String),
                imagePath: Value(item['imagePath'] as String?),
                quantity: Value(item['quantity'] as int? ?? 0),
                price: Value((item['price'] as num).toDouble()),
                costPrice: Value((item['costPrice'] as num?)?.toDouble()),
                minimumStock: Value(item['minimumStock'] as int? ?? 5),
                expirationDate: Value(
                  item['expirationDate'] != null
                      ? DateTime.parse(item['expirationDate'] as String)
                      : null,
                ),
                categoryId: Value(item['categoryId'] as int?),
                createdAt: item['createdAt'] != null
                    ? Value(DateTime.parse(item['createdAt'] as String))
                    : const Value.absent(),
                updatedAt: item['updatedAt'] != null
                    ? Value(DateTime.parse(item['updatedAt'] as String))
                    : const Value.absent(),
              ),
            );
      }

      for (final item in data['sales'] as List<dynamic>) {
        await database.into(database.sales).insert(
              SalesCompanion(
                id: item['id'] != null ? Value(item['id'] as int) : const Value.absent(),
                totalAmount: Value((item['totalAmount'] as num).toDouble()),
                totalCost: Value((item['totalCost'] as num?)?.toDouble() ?? 0),
                profit: Value((item['profit'] as num?)?.toDouble() ?? 0),
                cashReceived: Value((item['cashReceived'] as num).toDouble()),
                changeAmount: Value((item['changeAmount'] as num).toDouble()),
                createdAt: Value(DateTime.parse(item['createdAt'] as String)),
              ),
            );
      }

      final saleItems = data['saleItems'] as List<dynamic>? ?? const [];
      for (final item in saleItems) {
        await database.into(database.saleItems).insert(
              SaleItemsCompanion(
                id: item['id'] != null ? Value(item['id'] as int) : const Value.absent(),
                saleId: Value(item['saleId'] as int),
                productId: Value(item['productId'] as int),
                quantity: Value(item['quantity'] as int),
                price: Value((item['price'] as num).toDouble()),
                cost: Value((item['cost'] as num?)?.toDouble() ?? 0),
                subtotal: Value((item['subtotal'] as num).toDouble()),
                profit: Value((item['profit'] as num?)?.toDouble() ?? 0),
              ),
            );
      }

      final stockMovements =
          data['stockMovements'] as List<dynamic>? ?? const [];
      for (final item in stockMovements) {
        await database.into(database.stockMovements).insert(
              StockMovementsCompanion(
                id: item['id'] != null ? Value(item['id'] as int) : const Value.absent(),
                productId: Value(item['productId'] as int),
                type: Value(item['type'] as String),
                quantity: Value(item['quantity'] as int),
                previousQuantity: Value(item['previousQuantity'] as int),
                newQuantity: Value(item['newQuantity'] as int),
                reason: Value(item['reason'] as String?),
                createdAt: item['createdAt'] != null
                    ? Value(DateTime.parse(item['createdAt'] as String))
                    : const Value.absent(),
              ),
            );
      }

      for (final item in data['expenses'] as List<dynamic>) {
        await database.into(database.expenses).insert(
              ExpensesCompanion(
                id: item['id'] != null ? Value(item['id'] as int) : const Value.absent(),
                category: Value(item['category'] as String),
                amount: Value((item['amount'] as num).toDouble()),
                description: Value(item['description'] as String?),
                createdAt: Value(DateTime.parse(item['createdAt'] as String)),
              ),
            );
      }

      final notifications =
          data['notifications'] as List<dynamic>? ?? const [];
      for (final item in notifications) {
        await database.into(database.appNotifications).insert(
              AppNotificationsCompanion(
                id: item['id'] != null ? Value(item['id'] as int) : const Value.absent(),
                type: Value(item['type'] as String),
                title: Value(item['title'] as String),
                message: Value(item['message'] as String),
                productId: Value(item['productId'] as int?),
                isRead: Value(item['isRead'] as bool? ?? false),
                isDismissed: Value(item['isDismissed'] as bool? ?? false),
                createdAt: item['createdAt'] != null
                    ? Value(DateTime.parse(item['createdAt'] as String))
                    : const Value.absent(),
              ),
            );
      }
    });

    if (data['settings'] != null) {
      await settingsService.restoreFromJson(
        data['settings'] as Map<String, dynamic>,
      );
    }
  }

  Future<File> exportProductsCsv() async {
    final products = await database.select(database.products).get();
    final buffer = StringBuffer('Name,Quantity,Price,Cost,Minimum Stock\n');
    for (final product in products) {
      buffer.writeln(
        '"${product.name}",${product.quantity},${product.price},${product.costPrice ?? ''},${product.minimumStock}',
      );
    }

    final dir = await getApplicationDocumentsDirectory();
    final file = File(
      p.join(dir.path, 'products_export_${DateTime.now().millisecondsSinceEpoch}.csv'),
    );
    await file.writeAsString(buffer.toString());
    return file;
  }

  Map<String, dynamic> _productToJson(Product p) => {
        'id': p.id,
        'name': p.name,
        'imagePath': p.imagePath,
        'quantity': p.quantity,
        'price': p.price,
        'costPrice': p.costPrice,
        'minimumStock': p.minimumStock,
        'expirationDate': p.expirationDate?.toIso8601String(),
        'categoryId': p.categoryId,
        'createdAt': p.createdAt.toIso8601String(),
        'updatedAt': p.updatedAt.toIso8601String(),
      };

  Map<String, dynamic> _categoryToJson(Category c) => {
        'id': c.id,
        'name': c.name,
        'createdAt': c.createdAt.toIso8601String(),
      };

  Map<String, dynamic> _saleToJson(Sale s) => {
        'id': s.id,
        'totalAmount': s.totalAmount,
        'totalCost': s.totalCost,
        'profit': s.profit,
        'cashReceived': s.cashReceived,
        'changeAmount': s.changeAmount,
        'createdAt': s.createdAt.toIso8601String(),
      };

  Map<String, dynamic> _saleItemToJson(SaleItem s) => {
        'id': s.id,
        'saleId': s.saleId,
        'productId': s.productId,
        'quantity': s.quantity,
        'price': s.price,
        'cost': s.cost,
        'subtotal': s.subtotal,
        'profit': s.profit,
      };

  Map<String, dynamic> _movementToJson(StockMovement m) => {
        'id': m.id,
        'productId': m.productId,
        'type': m.type,
        'quantity': m.quantity,
        'previousQuantity': m.previousQuantity,
        'newQuantity': m.newQuantity,
        'reason': m.reason,
        'createdAt': m.createdAt.toIso8601String(),
      };

  Map<String, dynamic> _expenseToJson(Expense e) => {
        'id': e.id,
        'category': e.category,
        'amount': e.amount,
        'description': e.description,
        'createdAt': e.createdAt.toIso8601String(),
      };

  Map<String, dynamic> _notificationToJson(AppNotification n) => {
        'id': n.id,
        'type': n.type,
        'title': n.title,
        'message': n.message,
        'productId': n.productId,
        'isRead': n.isRead,
        'isDismissed': n.isDismissed,
        'createdAt': n.createdAt.toIso8601String(),
      };
}
