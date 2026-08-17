import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/app_widgets.dart';
import '../../database/database.dart';
import '../../shared/providers/app_providers.dart';
import 'cart_provider.dart';
import 'checkout_screen.dart';

class NewSaleScreen extends ConsumerStatefulWidget {
  const NewSaleScreen({super.key});

  @override
  ConsumerState<NewSaleScreen> createState() => _NewSaleScreenState();
}

class _NewSaleScreenState extends ConsumerState<NewSaleScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final cart = ref.watch(cartProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Sale'),
        actions: [
          if (cart.isNotEmpty)
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CheckoutScreen()),
              ),
              child: Text('Cart (${cart.length})'),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search product...',
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value.toLowerCase()),
            ),
          ),
          Expanded(
            child: productsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (products) {
                final filtered = products
                    .where((Product p) =>
                        p.quantity > 0 &&
                        (_query.isEmpty ||
                            p.name.toLowerCase().contains(_query)))
                    .toList();

                if (filtered.isEmpty) {
                  return const EmptyState(
                    icon: Icons.search_off_outlined,
                    title: 'No products found',
                    subtitle: 'Try a different search or add products first.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final product = filtered[index];
                    final inCart = cart.where((c) => c.product.id == product.id);
                    final cartQty =
                        inCart.isEmpty ? 0 : inCart.first.quantity;

                    return AppCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${CurrencyFormatter.format(product.price)} • ${product.quantity} left',
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: cartQty > 0
                                ? () => ref
                                    .read(cartProvider.notifier)
                                    .decrement(product)
                                : null,
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Text('$cartQty'),
                          IconButton(
                            onPressed: cartQty < product.quantity
                                ? () => ref
                                    .read(cartProvider.notifier)
                                    .increment(product)
                                : null,
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (cart.isNotEmpty)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: GradientButton(
                  label:
                      'Review Cart • ${CurrencyFormatter.format(ref.read(cartProvider.notifier).total)}',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CheckoutScreen(),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
