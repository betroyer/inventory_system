import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final _formatter = NumberFormat.currency(
    locale: 'en_PH',
    symbol: '₱',
    decimalDigits: 2,
  );

  static final _hero = NumberFormat.currency(
    locale: 'en_PH',
    symbol: '₱ ',
    decimalDigits: 0,
  );

  static String format(num amount) => _formatter.format(amount);

  static String hero(num amount) => _hero.format(amount);

  static String compact(num amount) {
    final abs = amount.abs();
    if (abs >= 1000000) {
      return '₱${(amount / 1000000).toStringAsFixed(abs >= 10000000 ? 0 : 1)}M';
    }
    if (abs >= 1000) {
      return '₱${(amount / 1000).toStringAsFixed(abs >= 10000 ? 0 : 1)}k';
    }
    return format(amount);
  }
}

class GrowthMath {
  static double percent(num current, num previous) {
    if (previous == 0) return current == 0 ? 0 : 100;
    return ((current - previous) / previous) * 100;
  }
}
