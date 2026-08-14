import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/app_widgets.dart';
import '../../database/database.dart';
import '../../shared/providers/app_providers.dart';

class RestockScreen extends ConsumerStatefulWidget {
  const RestockScreen({super.key, this.productId});

  final int? productId;

  @override
  ConsumerState<RestockScreen> createState() => _RestockScreenState();
}

class _RestockScreenState extends ConsumerState<RestockScreen> {
  Product? _selectedProduct;
  final _quantityController = TextEditingController();
  final _costController = TextEditingController();
  final _supplierController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.productId != null) {
      Future.microtask(() async {
        final product =
            await ref.read(productsDaoProvider).getProduct(widget.productId!);
        if (product != null && mounted) {
          setState(() => _selectedProduct = product);
        }
      });
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _costController.dispose();
    _supplierController.dispose();
    super.dispose();
  }

  Future<void> _confirmRestock() async {
    final product = _selectedProduct;
    final qty = int.tryParse(_quantityController.text.trim()) ?? 0;
    if (product == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a product and enter quantity.')),
      );
      return;
    }

    final newQty = product.quantity + qty;
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Confirm Restock',
      message:
          '${product.name}\nCurrent: ${product.quantity} + $qty = $newQty',
    );
    if (confirmed != true) return;

    setState(() => _isSaving = true);
    try {
      final dao = ref.read(productsDaoProvider);
      final cost = double.tryParse(_costController.text.trim());
      final supplier = _supplierController.text.trim();

      await dao.updateProductById(
        product.id,
        ProductsCompanion(
          quantity: Value(newQty),
          costPrice: cost != null ? Value(cost) : const Value.absent(),
          updatedAt: Value(DateTime.now()),
        ),
      );

      await dao.insertStockMovement(
        StockMovementsCompanion.insert(
          productId: product.id,
          type: 'restock',
          quantity: qty,
          previousQuantity: product.quantity,
          newQuantity: newQty,
          reason: Value(
            supplier.isNotEmpty ? 'Restock from $supplier' : 'Restock',
          ),
        ),
      );

      await ref.read(stockAlertServiceProvider).checkProduct(
            product.copyWith(
              quantity: newQty,
              costPrice: cost != null ? Value(cost) : Value(product.costPrice),
            ),
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restock completed successfully!')),
        );
        Navigator.pop(context, true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Restock')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          productsAsync.when(
            data: (products) => DropdownButtonFormField<Product>(
              value: _selectedProduct,
              decoration: const InputDecoration(labelText: 'Select Product *'),
              items: products
                  .map(
                    (Product p) => DropdownMenuItem<Product>(
                      value: p,
                      child: Text('${p.name} (${p.quantity} in stock)'),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _selectedProduct = value),
            ),
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('Error: $e'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _quantityController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Quantity Added *'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _costController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Purchase Cost (optional)',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _supplierController,
            decoration: const InputDecoration(
              labelText: 'Supplier (optional)',
            ),
          ),
          if (_selectedProduct != null &&
              _quantityController.text.isNotEmpty) ...[
            const SizedBox(height: 20),
            AppCard(
              child: Text(
                'New stock: ${_selectedProduct!.quantity + (int.tryParse(_quantityController.text.trim()) ?? 0)}',
              ),
            ),
          ],
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _isSaving ? null : _confirmRestock,
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Review & Confirm'),
          ),
        ],
      ),
    );
  }
}
