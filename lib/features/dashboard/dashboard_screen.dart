import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/store_health_calculator.dart';
import '../../core/widgets/app_widgets.dart';
import '../../database/database.dart';
import '../../shared/models/enums.dart';
import '../../shared/providers/app_providers.dart';
import '../expenses/add_expense_screen.dart';
import '../notifications/notifications_screen.dart';
import '../products/add_product_screen.dart';
import '../restock/restock_screen.dart';
import '../sales/new_sale_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dashboardSummaryProvider);
    final settings = ref.watch(settingsServiceProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider);
    final recentMovements = ref.watch(recentStockMovementsProvider);

    return Scaffold(
      body: SafeArea(
        child: summary.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (data) {
            final health = StoreHealthCalculator.calculate(
              products: data.products,
              todaySales: data.todaySales,
              todayProfit: data.todayProfit,
              lowStockCount: data.lowStockCount,
              outOfStockCount: data.outOfStockCount,
              expiringSoonCount: data.expiringSoonCount,
            );

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(dashboardSummaryProvider);
                await ref.read(stockAlertServiceProvider).checkAllProducts();
              },
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              settings.storeName,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'How is your store doing today?',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      unreadCount.when(
                        data: (count) => Stack(
                          clipBehavior: Clip.none,
                          children: [
                            IconButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const NotificationsScreen(),
                                ),
                              ),
                              icon: const Icon(Icons.notifications_outlined),
                            ),
                            if (count > 0)
                              Positioned(
                                right: 8,
                                top: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: AppColors.danger,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '$count',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Store Health',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              '${health.score}',
                              style: Theme.of(context)
                                  .textTheme
                                  .displaySmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                            ),
                            Text(
                              '/100',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(health.attentionMessage),
                        const SizedBox(height: 16),
                        _HealthBar(label: 'Inventory', value: health.inventoryHealth),
                        _HealthBar(label: 'Sales', value: health.salesHealth),
                        _HealthBar(label: 'Stock', value: health.stockHealth),
                        _HealthBar(label: 'Profit', value: health.profitHealth),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.3,
                    children: [
                      StatCard(
                        label: "Today's Sales",
                        value: CurrencyFormatter.format(data.todaySales),
                        icon: Icons.payments_outlined,
                      ),
                      StatCard(
                        label: 'Estimated Profit',
                        value: CurrencyFormatter.format(data.todayProfit),
                        icon: Icons.trending_up_outlined,
                        color: AppColors.success,
                      ),
                      StatCard(
                        label: 'Total Products',
                        value: '${data.totalProducts}',
                        icon: Icons.inventory_2_outlined,
                      ),
                      StatCard(
                        label: 'Low Stock',
                        value: '${data.lowStockCount}',
                        icon: Icons.warning_amber_outlined,
                        color: AppColors.warning,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const SectionHeader(title: 'Quick Actions'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _QuickAction(
                        icon: Icons.point_of_sale_outlined,
                        label: 'New Sale',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NewSaleScreen(),
                          ),
                        ),
                      ),
                      _QuickAction(
                        icon: Icons.add_box_outlined,
                        label: 'Restock',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RestockScreen(),
                          ),
                        ),
                      ),
                      _QuickAction(
                        icon: Icons.add_circle_outline,
                        label: 'Add Product',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AddProductScreen(),
                          ),
                        ),
                      ),
                      _QuickAction(
                        icon: Icons.receipt_long_outlined,
                        label: 'Add Expense',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AddExpenseScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SectionHeader(
                    title: 'Recent Activity',
                    action: null,
                  ),
                  const SizedBox(height: 12),
                  recentMovements.when(
                    data: (movements) {
                      if (movements.isEmpty) {
                        return const AppCard(
                          child: Text('No recent activity yet.'),
                        );
                      }
                      return Column(
                        children: movements.take(5).map((StockMovement m) {
                          return AppCard(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Icon(_iconForMovement(m.type)),
                                const SizedBox(width: 12),
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
                                        '${m.previousQuantity} → ${m.newQuantity}',
                                      ),
                                    ],
                                  ),
                                ),
                                Text(DateFormatter.time(m.createdAt)),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                    loading: () => const CircularProgressIndicator(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  IconData _iconForMovement(String type) {
    switch (StockMovementType.fromString(type)) {
      case StockMovementType.sale:
        return Icons.shopping_cart_outlined;
      case StockMovementType.restock:
        return Icons.add_box_outlined;
      default:
        return Icons.swap_horiz_outlined;
    }
  }
}

class _HealthBar extends StatelessWidget {
  const _HealthBar({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text(label), Text('$value%')],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: value / 100,
            borderRadius: BorderRadius.circular(8),
            minHeight: 8,
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
