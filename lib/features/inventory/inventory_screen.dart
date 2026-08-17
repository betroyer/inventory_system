import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../app/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/app_widgets.dart';
import '../../database/database.dart';
import '../../shared/models/enums.dart';
import '../../shared/models/product_extensions.dart';
import '../../shared/providers/app_providers.dart';
import '../expenses/add_expense_screen.dart';
import '../products/add_product_screen.dart';
import '../restock/restock_screen.dart';
import '../sales/new_sale_screen.dart';
import '../settings/settings_screen.dart';
import 'product_detail_screen.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  int? _selectedCategoryId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Store',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NewSaleScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.point_of_sale_outlined),
                  ),
                  IconButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SettingsScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.settings_outlined),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search products...',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) =>
                    setState(() => _query = value.toLowerCase()),
              ),
            ),
            categoriesAsync.when(
              data: (categories) {
                final labels = ['All', ...categories.map((c) => c.name)];
                final ids = <int?>[null, ...categories.map((c) => c.id)];
                final index = ids.indexOf(_selectedCategoryId);
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: UnderlineTabs(
                    labels: labels,
                    index: index < 0 ? 0 : index,
                    onChanged: (i) =>
                        setState(() => _selectedCategoryId = ids[i]),
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  _StoreAction(
                    icon: Icons.add_box_outlined,
                    label: 'Restock',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RestockScreen()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _StoreAction(
                    icon: Icons.receipt_long_outlined,
                    label: 'Expense',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AddExpenseScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: productsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (products) {
                  final filtered = products.where((Product p) {
                    final matchesQuery = _query.isEmpty ||
                        p.name.toLowerCase().contains(_query);
                    final matchesCategory = _selectedCategoryId == null ||
                        p.categoryId == _selectedCategoryId;
                    return matchesQuery && matchesCategory;
                  }).toList();

                  if (filtered.isEmpty) {
                    return EmptyState(
                      icon: Icons.storefront_outlined,
                      title: 'No products yet',
                      subtitle:
                          'Add your first product to start tracking inventory.',
                      action: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddProductScreen(),
                        ),
                      ),
                      actionLabel: 'Add Product',
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 88),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final product = filtered[index];
                      final status = product.stockStatus;
                      final statusColor = switch (status) {
                        StockStatus.inStock => AppColors.success,
                        StockStatus.lowStock => AppColors.warning,
                        StockStatus.outOfStock => AppColors.danger,
                      };
                      final statusLabel = switch (status) {
                        StockStatus.inStock => 'In Stock',
                        StockStatus.lowStock => 'Low Stock',
                        StockStatus.outOfStock => 'Out of Stock',
                      };

                      return AppCard(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ProductDetailScreen(productId: product.id),
                          ),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: product.imagePath != null
                                  ? Image.file(
                                      File(product.imagePath!),
                                      width: 56,
                                      height: 56,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      width: 56,
                                      height: 56,
                                      color: AppColors.primarySoft,
                                      child: const Icon(
                                        Icons.inventory_2_outlined,
                                        color: AppColors.primary,
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product.name,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    CurrencyFormatter.format(product.price),
                                    style: GoogleFonts.plusJakartaSans(
                                      color: AppColors.mutedText,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Stock ${NumberFormat('#,##0').format(product.quantity)}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: AppColors.mutedText,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                StockStatusChip(
                                  label: statusLabel,
                                  color: statusColor,
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddProductScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
    );
  }
}

class _StoreAction extends StatelessWidget {
  const _StoreAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
