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
      SELECT si.product_id, p.name, SUM(si.quantity) as total_qty, SUM(si.subtotal) as total_value
      FROM sale_items si
      INNER JOIN sales s ON s.id = si.sale_id
      INNER JOIN products p ON p.id = si.product_id
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
            productName: row.read<String>('name'),
            totalQuantity: row.read<int>('total_qty'),
            totalValue: row.read<double>('total_value'),
          ),
        )
        .toList();
  }

  Future<List<SalesTrendPoint>> getSalesTrend({
    required DateTime start,
    required DateTime end,
  }) async {
    final query = '''
      SELECT date(created_at) as day, SUM(total_amount) as total
      FROM sales
      WHERE created_at >= ? AND created_at < ?
      GROUP BY date(created_at)
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
          (row) => SalesTrendPoint(
            date: DateTime.parse(row.read<String>('day')),
            total: row.read<double>('total'),
          ),
        )
        .toList();
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
  });

  final int productId;
  final String productName;
  final int totalQuantity;
  final double totalValue;
}

class SalesTrendPoint {
  const SalesTrendPoint({required this.date, required this.total});

  final DateTime date;
  final double total;
}
