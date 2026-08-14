enum StockMovementType {
  sale('sale'),
  restock('restock'),
  damaged('damaged'),
  expired('expired'),
  returned('returned'),
  adjustment('adjustment');

  const StockMovementType(this.value);
  final String value;

  static StockMovementType fromString(String value) {
    return StockMovementType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => StockMovementType.adjustment,
    );
  }

  String get label {
    switch (this) {
      case StockMovementType.sale:
        return 'Sale';
      case StockMovementType.restock:
        return 'Restock';
      case StockMovementType.damaged:
        return 'Damaged';
      case StockMovementType.expired:
        return 'Expired';
      case StockMovementType.returned:
        return 'Returned';
      case StockMovementType.adjustment:
        return 'Manual Adjustment';
    }
  }
}

enum StockStatus {
  inStock,
  lowStock,
  outOfStock,
}

enum ExpirationStatus {
  normal,
  expiringSoon,
  expired,
  none,
}

enum AppNotificationType {
  lowStock('low_stock'),
  outOfStock('out_of_stock'),
  expiration('expiration');

  const AppNotificationType(this.value);
  final String value;

  static AppNotificationType fromString(String value) {
    return AppNotificationType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => AppNotificationType.lowStock,
    );
  }
}
