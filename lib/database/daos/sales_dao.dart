import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/tables.dart';

part 'sales_dao.g.dart';

@DriftAccessor(tables: [Sales, SaleItems, Products, StockMovements])
class SalesDao extends DatabaseAccessor<AppDatabase> with _$SalesDaoMixin {
  SalesDao(super.db);

  Stream<List<Sale>> watchAllSales() {
    return (select(sales)..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Stream<List<Sale>> watchSalesForDateRange(DateTime start, DateTime end) {
    return (select(sales)
          ..where((t) =>
              t.createdAt.isBiggerOrEqualValue(start) &
              t.createdAt.isSmallerThanValue(end))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Future<Sale?> getSale(int id) =>
      (select(sales)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<SaleItem>> getSaleItems(int saleId) {
    return (select(saleItems)..where((t) => t.saleId.equals(saleId))).get();
  }

  Future<int> completeSale({
    required double totalAmount,
    required double totalCost,
    required double profit,
    required double cashReceived,
    required double changeAmount,
    required List<SaleItemData> items,
  }) async {
    return transaction(() async {
      final saleId = await into(sales).insert(
        SalesCompanion.insert(
          totalAmount: totalAmount,
          totalCost: Value(totalCost),
          profit: Value(profit),
          cashReceived: cashReceived,
          changeAmount: changeAmount,
        ),
      );

      for (final item in items) {
        await into(saleItems).insert(
          SaleItemsCompanion.insert(
            saleId: saleId,
            productId: item.productId,
            quantity: item.quantity,
            price: item.price,
            cost: Value(item.cost),
            subtotal: item.subtotal,
            profit: Value(item.profit),
          ),
        );

        final product = await (select(products)
              ..where((t) => t.id.equals(item.productId)))
            .getSingle();
        final previousQty = product.quantity;
        final newQty = previousQty - item.quantity;
        if (newQty < 0) {
          throw StateError(
            'Insufficient stock for product #${item.productId}',
          );
        }

        await (update(products)..where((t) => t.id.equals(item.productId)))
            .write(
          ProductsCompanion(
            quantity: Value(newQty),
            updatedAt: Value(DateTime.now()),
          ),
        );

        await into(stockMovements).insert(
          StockMovementsCompanion.insert(
            productId: item.productId,
            type: 'sale',
            quantity: -item.quantity,
            previousQuantity: previousQty,
            newQuantity: newQty,
            reason: Value('Sale #$saleId'),
          ),
        );
      }

      return saleId;
    });
  }

  Future<DailySalesSummary> getDailySummary(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    final daySales = await (select(sales)
          ..where((t) =>
              t.createdAt.isBiggerOrEqualValue(start) &
              t.createdAt.isSmallerThanValue(end)))
        .get();

    final totalSales =
        daySales.fold<double>(0, (sum, s) => sum + s.totalAmount);
    final totalCost =
        daySales.fold<double>(0, (sum, s) => sum + s.totalCost);
    final totalProfit =
        daySales.fold<double>(0, (sum, s) => sum + s.profit);

    return DailySalesSummary(
      totalSales: totalSales,
      totalCost: totalCost,
      totalProfit: totalProfit,
      transactionCount: daySales.length,
    );
  }

  Future<List<ProductSalesRank>> getBestSellers({
    required DateTime start,
    required DateTime end,
    int limit = 10,
  }) async {
    final query = '''
      SELECT si.product_id, p.name, p.image_path,
             COALESCE(c.name, 'Other') as category,
             SUM(si.quantity) as total_qty, SUM(si.subtotal) as total_value
      FROM sale_items si
      INNER JOIN sales s ON s.id = si.sale_id
      INNER JOIN products p ON p.id = si.product_id
      LEFT JOIN categories c ON c.id = p.category_id
      WHERE s.created_at >= ? AND s.created_at < ?
      GROUP BY si.product_id
      ORDER BY total_qty DESC
      LIMIT ?
    ''';

    final rows = await customSelect(
      query,
      variables: [
        Variable.withDateTime(start),
        Variable.withDateTime(end),
        Variable.withInt(limit),
      ],
      readsFrom: {saleItems, sales, products},
    ).get();

    return rows
        .map(
          (row) => ProductSalesRank(
            productId: row.read<int>('product_id'),
            productName: row.readNullable<String>('name') ?? 'Unknown',
            totalQuantity: _readNumber(row, 'total_qty').round(),
            totalValue: _readNumber(row, 'total_value'),
            imagePath: row.readNullable<String>('image_path'),
            categoryName: row.readNullable<String>('category') ?? 'Other',
          ),
        )
        .toList();
  }

  Future<List<SalesTrendPoint>> getSalesTrend({
    required DateTime start,
    required DateTime end,
  }) async {
    final query = '''
      SELECT date(created_at, 'unixepoch') as day, SUM(total_amount) as total
      FROM sales
      WHERE created_at >= ? AND created_at < ?
      GROUP BY day
      ORDER BY day ASC
    ''';

    final rows = await customSelect(
      query,
      variables: [
        Variable.withDateTime(start),
        Variable.withDateTime(end),
      ],
      readsFrom: {sales},
    ).get();

    return rows
        .map(
          (row) {
            final day = row.readNullable<String>('day');
            if (day == null) return null;
            return SalesTrendPoint(
              date: DateTime.parse(day),
              total: _readNumber(row, 'total'),
            );
          },
        )
        .whereType<SalesTrendPoint>()
        .toList();
  }

  Future<double> getUnitsSold({
    required DateTime start,
    required DateTime end,
  }) async {
    final rows = await customSelect(
      '''
      SELECT COALESCE(SUM(si.quantity), 0) as total_qty
      FROM sale_items si
      INNER JOIN sales s ON s.id = si.sale_id
      WHERE s.created_at >= ? AND s.created_at < ?
      ''',
      variables: [
        Variable.withDateTime(start),
        Variable.withDateTime(end),
      ],
      readsFrom: {saleItems, sales},
    ).get();
    if (rows.isEmpty) return 0;
    return _readNumber(rows.first, 'total_qty');
  }

  Future<RangeTotals> getRangeTotals(DateTime start, DateTime end) async {
    final daySales = await (select(sales)
          ..where((t) =>
              t.createdAt.isBiggerOrEqualValue(start) &
              t.createdAt.isSmallerThanValue(end)))
        .get();
    final units = await getUnitsSold(start: start, end: end);
    return RangeTotals(
      totalSales: daySales.fold<double>(0, (sum, s) => sum + s.totalAmount),
      totalProfit: daySales.fold<double>(0, (sum, s) => sum + s.profit),
      transactionCount: daySales.length,
      unitsSold: units,
    );
  }

  Future<List<SalesTrendPoint>> getMonthlySalesTrend({int months = 6}) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - (months - 1), 1);
    final end = DateTime(now.year, now.month + 1, 1);

    final rows = await customSelect(
      '''
      SELECT strftime('%Y-%m', created_at, 'unixepoch') as month,
             SUM(total_amount) as total
      FROM sales
      WHERE created_at >= ? AND created_at < ?
      GROUP BY month
      ORDER BY month ASC
      ''',
      variables: [
        Variable.withDateTime(start),
        Variable.withDateTime(end),
      ],
      readsFrom: {sales},
    ).get();

    final byMonth = <String, double>{};
    for (final row in rows) {
      final key = row.readNullable<String>('month');
      if (key == null) continue;
      byMonth[key] = _readNumber(row, 'total');
    }

    final points = <SalesTrendPoint>[];
    for (var i = 0; i < months; i++) {
      final date = DateTime(now.year, now.month - (months - 1 - i), 1);
      final key =
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';
      points.add(SalesTrendPoint(date: date, total: byMonth[key] ?? 0));
    }
    return points;
  }

  Future<List<CategoryMonthSales>> getCategoryMonthlySales({
    int months = 6,
  }) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - (months - 1), 1);
    final end = DateTime(now.year, now.month + 1, 1);

    final rows = await customSelect(
      '''
      SELECT strftime('%Y-%m', s.created_at, 'unixepoch') as month,
             COALESCE(c.name, 'Other') as category,
             SUM(si.subtotal) as total
      FROM sale_items si
      INNER JOIN sales s ON s.id = si.sale_id
      INNER JOIN products p ON p.id = si.product_id
      LEFT JOIN categories c ON c.id = p.category_id
      WHERE s.created_at >= ? AND s.created_at < ?
      GROUP BY month, category
      ORDER BY month ASC
      ''',
      variables: [
        Variable.withDateTime(start),
        Variable.withDateTime(end),
      ],
      readsFrom: {saleItems, sales, products},
    ).get();

    return rows
        .map((row) {
          final month = row.readNullable<String>('month');
          if (month == null) return null;
          return CategoryMonthSales(
            monthKey: month,
            category: row.readNullable<String>('category') ?? 'Other',
            total: _readNumber(row, 'total'),
          );
        })
        .whereType<CategoryMonthSales>()
        .toList();
  }

  double _readNumber(QueryRow row, String column) {
    final value = row.data[column];
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }
}

class SaleItemData {
  const SaleItemData({
    required this.productId,
    required this.quantity,
    required this.price,
    required this.cost,
    required this.subtotal,
    required this.profit,
  });

  final int productId;
  final int quantity;
  final double price;
  final double cost;
  final double subtotal;
  final double profit;
}

class DailySalesSummary {
  const DailySalesSummary({
    required this.totalSales,
    required this.totalCost,
    required this.totalProfit,
    required this.transactionCount,
  });

  final double totalSales;
  final double totalCost;
  final double totalProfit;
  final int transactionCount;
}

class ProductSalesRank {
  const ProductSalesRank({
    required this.productId,
    required this.productName,
    required this.totalQuantity,
    required this.totalValue,
    this.imagePath,
    this.categoryName = 'Other',
  });

  final int productId;
  final String productName;
  final int totalQuantity;
  final double totalValue;
  final String? imagePath;
  final String categoryName;
}

class RangeTotals {
  const RangeTotals({
    required this.totalSales,
    required this.totalProfit,
    required this.transactionCount,
    required this.unitsSold,
  });

  final double totalSales;
  final double totalProfit;
  final int transactionCount;
  final double unitsSold;
}

class CategoryMonthSales {
  const CategoryMonthSales({
    required this.monthKey,
    required this.category,
    required this.total,
  });

  final String monthKey;
  final String category;
  final double total;
}

class SalesTrendPoint {
  const SalesTrendPoint({required this.date, required this.total});

  final DateTime date;
  final double total;
}
