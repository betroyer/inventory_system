import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/app_widgets.dart';
import '../../database/daos/sales_dao.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/providers/report_providers.dart';
import 'cart_provider.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _cashController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _cashController.dispose();
    super.dispose();
  }

  double get _total => ref.read(cartProvider.notifier).total;

  double? get _change {
    final cash = double.tryParse(_cashController.text.trim());
    if (cash == null) return null;
    return cash - _total;
  }

  Future<void> _completeSale() async {
    final cash = double.tryParse(_cashController.text.trim());
    if (cash == null || cash < _total) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter sufficient cash amount.')),
      );
      return;
    }

    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Complete Sale',
      message:
          'Total: ${CurrencyFormatter.format(_total)}\nCash: ${CurrencyFormatter.format(cash)}\nChange: ${CurrencyFormatter.format(cash - _total)}',
      confirmLabel: 'Complete Sale',
    );
    if (confirmed != true) return;

    setState(() => _isProcessing = true);
    try {
      final cart = ref.read(cartProvider);
      final productsDao = ref.read(productsDaoProvider);

      for (final item in cart) {
        final current =
            await productsDao.getProduct(item.product.id);
        if (current == null || current.quantity < item.quantity) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  current == null
                      ? '${item.product.name} is no longer available.'
                      : 'Not enough stock for ${item.product.name} '
                          '(only ${current.quantity} left).',
                ),
              ),
            );
          }
          return;
        }
      }

      final salesDao = ref.read(salesDaoProvider);
      final alertService = ref.read(stockAlertServiceProvider);

      await salesDao.completeSale(
        totalAmount: ref.read(cartProvider.notifier).total,
        totalCost: ref.read(cartProvider.notifier).totalCost,
        profit: ref.read(cartProvider.notifier).totalProfit,
        cashReceived: cash,
        changeAmount: cash - _total,
        items: cart
            .map(
              (item) => SaleItemData(
                productId: item.product.id,
                quantity: item.quantity,
                price: item.product.price,
                cost: item.product.costPrice ?? 0,
                subtotal: item.subtotal,
                profit: item.profit,
              ),
            )
            .toList(),
      );

      for (final item in cart) {
        final updatedQty = item.product.quantity - item.quantity;
        await alertService.checkProduct(
          item.product.copyWith(quantity: updatedQty),
        );
      }

      ref.read(cartProvider.notifier).clear();
      ref.invalidate(dashboardSummaryProvider);
      ref.invalidate(reportDataProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sale completed successfully!')),
        );
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } on StateError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final change = _change;

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SectionHeader(title: 'Cart'),
          const SizedBox(height: 12),
          ...cart.map(
            (item) => AppCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text('${item.product.name} × ${item.quantity}'),
                  ),
                  Text(CurrencyFormatter.format(item.subtotal)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          AppCard(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total'),
                    Text(
                      CurrencyFormatter.format(_total),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _cashController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Cash Received',
                    prefixText: '₱ ',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                if (change != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Change'),
                      Text(
                        CurrencyFormatter.format(change),
                        style: TextStyle(
                          color: change >= 0 ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isProcessing ? null : _completeSale,
            child: _isProcessing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Complete Sale'),
          ),
        ],
      ),
    );
  }
}
