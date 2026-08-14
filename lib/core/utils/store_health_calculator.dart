import '../../database/database.dart';

class StoreHealthResult {
  const StoreHealthResult({
    required this.score,
    required this.inventoryHealth,
    required this.salesHealth,
    required this.stockHealth,
    required this.profitHealth,
    required this.attentionMessage,
  });

  final int score;
  final int inventoryHealth;
  final int salesHealth;
  final int stockHealth;
  final int profitHealth;
  final String attentionMessage;
}

class StoreHealthCalculator {
  static StoreHealthResult calculate({
    required List<Product> products,
    required double todaySales,
    required double todayProfit,
    required int lowStockCount,
    required int outOfStockCount,
    required int expiringSoonCount,
  }) {
    final totalProducts = products.length;
    final inStockCount =
        products.where((p) => p.quantity > p.minimumStock).length;

    final inventoryHealth = totalProducts == 0
        ? 50
        : ((inStockCount / totalProducts) * 100).round().clamp(0, 100);

    final stockHealth = totalProducts == 0
        ? 50
        : (100 -
                ((lowStockCount * 8 + outOfStockCount * 15) /
                        totalProducts *
                        10)
                    .clamp(0, 100))
            .round()
            .clamp(0, 100);

    final salesHealth = todaySales > 0
        ? (50 + (todaySales / 1000 * 50).clamp(0, 50)).round()
        : 30;

    final profitHealth = todayProfit > 0
        ? (50 + (todayProfit / 500 * 50).clamp(0, 50)).round()
        : 30;

    final score = ((inventoryHealth +
                salesHealth +
                stockHealth +
                profitHealth) /
            4)
        .round()
        .clamp(0, 100);

    String attentionMessage;
    if (outOfStockCount > 0) {
      attentionMessage =
          '$outOfStockCount product${outOfStockCount == 1 ? '' : 's'} are out of stock.';
    } else if (lowStockCount > 0) {
      attentionMessage =
          '$lowStockCount product${lowStockCount == 1 ? '' : 's'} are approaching their minimum stock level.';
    } else if (expiringSoonCount > 0) {
      attentionMessage =
          '$expiringSoonCount product${expiringSoonCount == 1 ? '' : 's'} expiring soon.';
    } else if (totalProducts == 0) {
      attentionMessage = 'Add your first product to get started.';
    } else {
      attentionMessage = 'Your store is in good shape today.';
    }

    return StoreHealthResult(
      score: score,
      inventoryHealth: inventoryHealth,
      salesHealth: salesHealth,
      stockHealth: stockHealth,
      profitHealth: profitHealth,
      attentionMessage: attentionMessage,
    );
  }
}
