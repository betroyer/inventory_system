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
      'version': 1,
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
              CategoriesCompanion.insert(name: item['name'] as String),
            );
      }

      for (final item in data['products'] as List<dynamic>) {
        await database.into(database.products).insert(
              ProductsCompanion.insert(
                name: item['name'] as String,
                imagePath: Value(item['imagePath'] as String?),
                quantity: Value(item['quantity'] as int? ?? 0),
                price: (item['price'] as num).toDouble(),
                costPrice: Value((item['costPrice'] as num?)?.toDouble()),
                minimumStock: Value(item['minimumStock'] as int? ?? 5),
                expirationDate: Value(
                  item['expirationDate'] != null
                      ? DateTime.parse(item['expirationDate'] as String)
                      : null,
                ),
                categoryId: Value(item['categoryId'] as int?),
              ),
            );
      }

      for (final item in data['sales'] as List<dynamic>) {
        await database.into(database.sales).insert(
              SalesCompanion.insert(
                totalAmount: (item['totalAmount'] as num).toDouble(),
                totalCost: Value((item['totalCost'] as num?)?.toDouble() ?? 0),
                profit: Value((item['profit'] as num?)?.toDouble() ?? 0),
                cashReceived: (item['cashReceived'] as num).toDouble(),
                changeAmount: (item['changeAmount'] as num).toDouble(),
                createdAt: Value(DateTime.parse(item['createdAt'] as String)),
              ),
            );
      }

      for (final item in data['expenses'] as List<dynamic>) {
        await database.into(database.expenses).insert(
              ExpensesCompanion.insert(
                category: item['category'] as String,
                amount: (item['amount'] as num).toDouble(),
                description: Value(item['description'] as String?),
                createdAt: Value(DateTime.parse(item['createdAt'] as String)),
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
        'name': p.name,
        'imagePath': p.imagePath,
        'quantity': p.quantity,
        'price': p.price,
        'costPrice': p.costPrice,
        'minimumStock': p.minimumStock,
        'expirationDate': p.expirationDate?.toIso8601String(),
        'categoryId': p.categoryId,
      };

  Map<String, dynamic> _categoryToJson(Category c) => {'name': c.name};

  Map<String, dynamic> _saleToJson(Sale s) => {
        'totalAmount': s.totalAmount,
        'totalCost': s.totalCost,
        'profit': s.profit,
        'cashReceived': s.cashReceived,
        'changeAmount': s.changeAmount,
        'createdAt': s.createdAt.toIso8601String(),
      };

  Map<String, dynamic> _saleItemToJson(SaleItem s) => {
        'saleId': s.saleId,
        'productId': s.productId,
        'quantity': s.quantity,
        'price': s.price,
        'cost': s.cost,
        'subtotal': s.subtotal,
        'profit': s.profit,
      };

  Map<String, dynamic> _movementToJson(StockMovement m) => {
        'productId': m.productId,
        'type': m.type,
        'quantity': m.quantity,
        'previousQuantity': m.previousQuantity,
        'newQuantity': m.newQuantity,
        'reason': m.reason,
        'createdAt': m.createdAt.toIso8601String(),
      };

  Map<String, dynamic> _expenseToJson(Expense e) => {
        'category': e.category,
        'amount': e.amount,
        'description': e.description,
        'createdAt': e.createdAt.toIso8601String(),
      };

  Map<String, dynamic> _notificationToJson(AppNotification n) => {
        'type': n.type,
        'title': n.title,
        'message': n.message,
        'productId': n.productId,
        'isRead': n.isRead,
        'isDismissed': n.isDismissed,
        'createdAt': n.createdAt.toIso8601String(),
      };
}
