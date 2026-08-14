import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/database.dart';

class CartItem {
  const CartItem({required this.product, required this.quantity});

  final Product product;
  final int quantity;

  double get subtotal => product.price * quantity;
  double get profit =>
      (product.price - (product.costPrice ?? 0)) * quantity;
  double get cost => (product.costPrice ?? 0) * quantity;
}

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super(const []);

  double get total => state.fold(0, (sum, item) => sum + item.subtotal);
  double get totalCost => state.fold(0, (sum, item) => sum + item.cost);
  double get totalProfit => state.fold(0, (sum, item) => sum + item.profit);

  void increment(Product product) {
    if (product.quantity <= 0) return;
    final index = state.indexWhere((c) => c.product.id == product.id);
    if (index >= 0) {
      final item = state[index];
      if (item.quantity >= product.quantity) return;
      state = [
        ...state.sublist(0, index),
        CartItem(product: product, quantity: item.quantity + 1),
        ...state.sublist(index + 1),
      ];
    } else {
      state = [...state, CartItem(product: product, quantity: 1)];
    }
  }

  void decrement(Product product) {
    final index = state.indexWhere((c) => c.product.id == product.id);
    if (index < 0) return;
    final item = state[index];
    if (item.quantity <= 1) {
      state = [...state.sublist(0, index), ...state.sublist(index + 1)];
    } else {
      state = [
        ...state.sublist(0, index),
        CartItem(product: product, quantity: item.quantity - 1),
        ...state.sublist(index + 1),
      ];
    }
  }

  void clear() => state = const [];
}

final cartProvider =
    StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  return CartNotifier();
});
