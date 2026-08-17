import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../app/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/app_widgets.dart';
import '../../shared/providers/app_providers.dart';
import '../expenses/add_expense_screen.dart';
import '../notifications/notifications_screen.dart';
import '../products/add_product_screen.dart';
import '../restock/restock_screen.dart';
import '../sales/new_sale_screen.dart';
import '../settings/settings_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dashboardSummaryProvider);
    final settings = ref.watch(settingsServiceProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      body: SafeArea(
        child: summary.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (data) {
            final updated = DateFormatter.longDate(DateTime.now());
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(dashboardSummaryProvider);
                await ref.read(stockAlertServiceProvider).checkAllProducts();
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
                  _HomeHeader(
                    storeName: settings.storeName,
                    photoPath: settings.storePhotoPath,
                    unread: unreadCount,
                  ),
                  const SizedBox(height: 20),
                  _ProfitHeroCard(
                    profit: data.weekProfit,
                    growth: GrowthMath.percent(
                      data.weekProfit,
                      data.prevWeekProfit,
                    ),
                    sparkline: data.sparkline,
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.95,
                    children: [
                      MiniStatCard(
                        label: 'Total Products',
                        value: '${data.totalProducts}',
                        icon: Icons.inventory_2_outlined,
                        growth: GrowthMath.percent(
                          data.totalProducts,
                          data.productGrowthBase,
                        ),
                        updatedAt: updated,
                      ),
                      MiniStatCard(
                        label: 'Product Category',
                        value: '${data.categoryCount}',
                        icon: Icons.category_outlined,
                        growth: GrowthMath.percent(
                          data.categoryCount,
                          data.categoryGrowthBase,
                        ),
                        updatedAt: updated,
                        color: const Color(0xFF4C8DFF),
                      ),
                      MiniStatCard(
                        label: 'Total Sold',
                        value: NumberFormat('#,##0')
                            .format(data.monthUnitsSold.round()),
                        icon: Icons.shopping_bag_outlined,
                        growth: GrowthMath.percent(
                          data.monthUnitsSold,
                          data.prevMonthUnitsSold,
                        ),
                        updatedAt: updated,
                        color: const Color(0xFF3EC6D9),
                      ),
                      MiniStatCard(
                        label: 'Monthly Income',
                        value: CurrencyFormatter.compact(data.monthIncome),
                        icon: Icons.account_balance_wallet_outlined,
                        growth: GrowthMath.percent(
                          data.monthIncome,
                          data.prevMonthIncome,
                        ),
                        updatedAt: updated,
                        color: const Color(0xFFF5C242),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  GradientButton(
                    label: 'New Sale',
                    icon: Icons.point_of_sale_rounded,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NewSaleScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _QuickChip(
                        icon: Icons.add_box_outlined,
                        label: 'Restock',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RestockScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _QuickChip(
                        icon: Icons.add_circle_outline,
                        label: 'Add Product',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AddProductScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _QuickChip(
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
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.storeName,
    required this.photoPath,
    required this.unread,
  });

  final String storeName;
  final String? photoPath;
  final AsyncValue<int> unread;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
          child: _Avatar(photoPath: photoPath, storeName: storeName),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome Back!',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppColors.mutedText,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$storeName 👋',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        unread.when(
          data: (count) => _BellButton(count: count),
          loading: () => const _BellButton(count: 0),
          error: (_, _) => const _BellButton(count: 0),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.photoPath, required this.storeName});

  final String? photoPath;
  final String storeName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.primaryGradient,
        image: photoPath != null
            ? DecorationImage(
                image: FileImage(File(photoPath!)),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: photoPath == null
          ? Center(
              child: Text(
                storeName.isEmpty ? 'S' : storeName[0].toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            )
          : null,
    );
  }
}

class _BellButton extends StatelessWidget {
  const _BellButton({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          style: IconButton.styleFrom(
            backgroundColor:
                isDark ? const Color(0xFF2A2B32) : const Color(0xFFF3F3F5),
            shape: const CircleBorder(),
          ),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          ),
          icon: const Icon(Icons.notifications_none_rounded),
        ),
        if (count > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0xFFFF3B30),
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

class _ProfitHeroCard extends StatelessWidget {
  const _ProfitHeroCard({
    required this.profit,
    required this.growth,
    required this.sparkline,
  });

  final double profit;
  final double growth;
  final List<double> sparkline;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 168,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 78,
            child: Sparkline(
              values: sparkline.length >= 2
                  ? sparkline
                  : const [0, 2, 1, 4, 3, 5, 4],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profit amount',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: Text(
                    CurrencyFormatter.hero(profit),
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 28,
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    GrowthBadge(percent: growth, compact: false, onGradient: true),
                    const SizedBox(width: 8),
                    Text(
                      'From the previous week',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white.withValues(alpha: 0.86),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
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
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
