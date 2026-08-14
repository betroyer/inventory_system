import 'dart:io';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/app_widgets.dart';
import '../../database/database.dart';
import '../../shared/models/enums.dart';
import '../../shared/models/product_extensions.dart';
import '../../shared/providers/app_providers.dart';
import '../products/add_product_screen.dart';
import '../restock/restock_screen.dart';

class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final int productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider);
    final movementsAsync = ref.watch(
      StreamProvider((ref) => ref
          .watch(productsDaoProvider)
          .watchStockMovementsForProduct(productId)),
    );
    final settings = ref.watch(settingsServiceProvider);

    return productsAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (products) {
        final product = products.cast<Product?>().firstWhere(
              (p) => p?.id == productId,
              orElse: () => null,
            );
        if (product == null) {
          return const Scaffold(
            body: Center(child: Text('Product not found')),
          );
        }

        final status = product.stockStatus;
        final expStatus = product.expirationStatus(settings.expirationWarningDays);

        return Scaffold(
          appBar: AppBar(
            title: Text(product.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddProductScreen(product: product),
                  ),
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (product.imagePath != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.file(
                    File(product.imagePath!),
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(height: 20),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      CurrencyFormatter.format(product.price),
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text('Current stock: ${product.quantity}'),
                    Text('Minimum stock: ${product.minimumStock}'),
                    if (product.costPrice != null)
                      Text('Cost: ${CurrencyFormatter.format(product.costPrice!)}'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        StockStatusChip(
                          label: switch (status) {
                            StockStatus.inStock => 'In Stock',
                            StockStatus.lowStock => 'Low Stock',
                            StockStatus.outOfStock => 'Out of Stock',
                          },
                          color: switch (status) {
                            StockStatus.inStock => AppColors.success,
                            StockStatus.lowStock => AppColors.warning,
                            StockStatus.outOfStock => AppColors.danger,
                          },
                        ),
                        if (expStatus != ExpirationStatus.none)
                          StockStatusChip(
                            label: switch (expStatus) {
                              ExpirationStatus.normal => 'Fresh',
                              ExpirationStatus.expiringSoon => 'Expiring Soon',
                              ExpirationStatus.expired => 'Expired',
                              ExpirationStatus.none => '',
                            },
                            color: switch (expStatus) {
                              ExpirationStatus.normal => AppColors.success,
                              ExpirationStatus.expiringSoon => AppColors.warning,
                              ExpirationStatus.expired => AppColors.danger,
                              ExpirationStatus.none => Colors.grey,
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RestockScreen(productId: product.id),
                        ),
                      ),
                      icon: const Icon(Icons.add_box_outlined),
                      label: const Text('Restock'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _adjustStock(context, ref, product),
                      icon: const Icon(Icons.tune_outlined),
                      label: const Text('Adjust'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const SectionHeader(title: 'Stock History'),
              const SizedBox(height: 12),
              movementsAsync.when(
                data: (movements) {
                  if (movements.isEmpty) {
                    return const AppCard(child: Text('No stock movements yet.'));
                  }
                  return Column(
                    children: movements.map((m) {
                      return AppCard(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    StockMovementType.fromString(m.type).label,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${m.previousQuantity} → ${m.newQuantity} (${m.quantity >= 0 ? '+' : ''}${m.quantity})',
                                  ),
                                  if (m.reason != null) Text(m.reason!),
                                ],
                              ),
                            ),
                            Text(DateFormatter.dateTime(m.createdAt)),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => _deleteProduct(context, ref, product),
                icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                label: const Text(
                  'Delete Product',
                  style: TextStyle(color: AppColors.danger),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _adjustStock(
    BuildContext context,
    WidgetRef ref,
    Product product,
  ) async {
    final controller = TextEditingController(text: product.quantity.toString());
    final newQty = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adjust Stock'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'New quantity'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final qty = int.tryParse(controller.text.trim());
              if (qty != null) Navigator.pop(context, qty);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newQty == null || newQty == product.quantity) return;

    final dao = ref.read(productsDaoProvider);
    await dao.updateProductQuantity(product.id, newQty);
    await dao.insertStockMovement(
      StockMovementsCompanion.insert(
        productId: product.id,
        type: 'adjustment',
        quantity: newQty - product.quantity,
        previousQuantity: product.quantity,
        newQuantity: newQty,
        reason: const Value('Manual adjustment'),
      ),
    );
    await ref.read(stockAlertServiceProvider).checkProduct(
          product.copyWith(quantity: newQty),
        );
  }

  Future<void> _deleteProduct(
    BuildContext context,
    WidgetRef ref,
    Product product,
  ) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete Product',
      message: 'Are you sure you want to delete ${product.name}?',
      confirmLabel: 'Delete',
    );
    if (confirmed != true) return;

    await ref.read(productsDaoProvider).deleteProduct(product.id);
    if (context.mounted) Navigator.pop(context);
  }
}
