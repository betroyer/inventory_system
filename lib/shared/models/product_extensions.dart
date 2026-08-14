import '../../database/database.dart';
import 'enums.dart';

extension ProductExtensions on Product {
  StockStatus get stockStatus {
    if (quantity <= 0) return StockStatus.outOfStock;
    if (quantity <= minimumStock) return StockStatus.lowStock;
    return StockStatus.inStock;
  }

  ExpirationStatus expirationStatus(int warningDays) {
    if (expirationDate == null) return ExpirationStatus.none;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final exp = DateTime(
      expirationDate!.year,
      expirationDate!.month,
      expirationDate!.day,
    );
    if (exp.isBefore(today)) return ExpirationStatus.expired;
    if (exp.difference(today).inDays <= warningDays) {
      return ExpirationStatus.expiringSoon;
    }
    return ExpirationStatus.normal;
  }
}
