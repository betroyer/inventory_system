import 'dart:io';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../app/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/app_widgets.dart';
import '../../database/daos/sales_dao.dart';
import '../../shared/providers/report_providers.dart';
import '../inventory/product_detail_screen.dart';

enum _AnalysisTab { sale, product }
enum _ChartRange { weekly, monthly }
enum _ProductSort { bestseller, name }

class AnalysisScreen extends ConsumerStatefulWidget {
  const AnalysisScreen({super.key});

  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen> {
  _AnalysisTab _tab = _AnalysisTab.sale;
  _ChartRange _range = _ChartRange.monthly;
  _ProductSort _sort = _ProductSort.bestseller;
  String _categoryFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final analysisAsync = ref.watch(analysisDataProvider);

    return Scaffold(
      body: SafeArea(
        child: analysisAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (data) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(analysisDataProvider);
              await ref.read(analysisDataProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                Text(
                  'Analysis',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                PillToggle<_AnalysisTab>(
                  values: const [_AnalysisTab.sale, _AnalysisTab.product],
                  labels: const ['Sale', 'Product'],
                  selected: _tab,
                  onChanged: (value) => setState(() => _tab = value),
                ),
                const SizedBox(height: 18),
                if (_tab == _AnalysisTab.sale)
                  ..._saleTab(data)
                else
                  ..._productTab(data),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _saleTab(AnalysisData data) {
    final points = _range == _ChartRange.monthly
        ? data.monthlyTrend
        : _filledWeek(data.weeklyTrend);
    final progress = data.salesTarget <= 0
        ? 0.0
        : (data.monthSales / data.salesTarget).clamp(0.0, 1.0);

    return [
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Sales statistics',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                FilterDropdown<_ChartRange>(
                  value: _range,
                  items: const [_ChartRange.monthly, _ChartRange.weekly],
                  labels: const ['Monthly', 'Weekly'],
                  onChanged: (value) => setState(() => _range = value),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: _SalesLineChart(
                points: points,
                monthly: _range == _ChartRange.monthly,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Target Prediction',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              CurrencyFormatter.hero(data.salesTarget),
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 28,
              ),
            ),
            const SizedBox(height: 16),
            GradientProgressBar(value: progress),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  CurrencyFormatter.format(data.monthSales),
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    color: AppColors.mutedText,
                  ),
                ),
                const Spacer(),
                Text(
                  '${(progress * 100).round()}%',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _productTab(AnalysisData data) {
    final months = data.monthlyTrend.map((p) => p.date).toList();
    final categories = {
      ...data.categorySales.map((c) => c.category),
    }.toList()
      ..sort();
    if (categories.isEmpty) {
      categories.addAll(['Food', 'Drinks', 'Snacks', 'Other']);
    }

    var products = [
      ...(_range == _ChartRange.monthly ? data.products : data.weeklyProducts),
    ];
    if (_categoryFilter != 'All') {
      products = products
          .where(
            (p) => p.categoryName.toLowerCase() == _categoryFilter.toLowerCase(),
          )
          .toList();
    }
    if (_sort == _ProductSort.name) {
      products.sort((a, b) => a.productName.compareTo(b.productName));
    }

    final tabLabels = ['All', ...categories.take(4)];
    final selectedIndex = tabLabels.indexWhere(
      (label) => label.toLowerCase() == _categoryFilter.toLowerCase(),
    );

    return [
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Product sale',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: _CategoryBarChart(
                months: months,
                rows: data.categorySales,
                categories: categories,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 14,
              runSpacing: 8,
              children: [
                for (final name in categories)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppColors.categoryColor(name),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        name,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      AppCard(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Product',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                FilterDropdown<_ChartRange>(
                  value: _range,
                  items: const [_ChartRange.monthly, _ChartRange.weekly],
                  labels: const ['Monthly', 'Weekly'],
                  onChanged: (value) => setState(() => _range = value),
                ),
                const SizedBox(width: 8),
                FilterDropdown<_ProductSort>(
                  value: _sort,
                  items: const [_ProductSort.bestseller, _ProductSort.name],
                  labels: const ['Bestseller', 'Name'],
                  onChanged: (value) => setState(() => _sort = value),
                ),
              ],
            ),
            const SizedBox(height: 8),
            UnderlineTabs(
              labels: tabLabels,
              index: selectedIndex < 0 ? 0 : selectedIndex,
              onChanged: (i) =>
                  setState(() => _categoryFilter = tabLabels[i]),
            ),
            const SizedBox(height: 8),
            if (products.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('No product sales yet.')),
              )
            else
              ...products.map(
                (item) => _ProductSaleTile(item: item),
              ),
          ],
        ),
      ),
    ];
  }

  List<SalesTrendPoint> _filledWeek(List<SalesTrendPoint> raw) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final filled = <SalesTrendPoint>[];
    for (var i = 0; i < 7; i++) {
      final day = start.add(Duration(days: i));
      final match = raw.where(
        (p) =>
            p.date.year == day.year &&
            p.date.month == day.month &&
            p.date.day == day.day,
      );
      filled.add(
        SalesTrendPoint(
          date: day,
          total: match.isEmpty ? 0 : match.first.total,
        ),
      );
    }
    return filled;
  }
}

class _SalesLineChart extends StatelessWidget {
  const _SalesLineChart({required this.points, required this.monthly});

  final List<SalesTrendPoint> points;
  final bool monthly;

  @override
  Widget build(BuildContext context) {
    final values = points.map((p) => p.total).toList();
    final maxY = values.isEmpty
        ? 8000.0
        : math.max(values.reduce(math.max) * 1.2, 1000.0);
    final spots = [
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].total),
    ];
    if (spots.length < 2) {
      spots.addAll(const [FlSpot(0, 0), FlSpot(1, 0)]);
    }

    final muted = AppColors.mutedText;
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: muted.withValues(alpha: 0.18),
            strokeWidth: 1,
            dashArray: [4, 6],
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: maxY / 4,
              getTitlesWidget: (value, meta) => Text(
                _axisLabel(value),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  color: muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final i = value.round();
                if (i < 0 || i >= points.length) {
                  return const SizedBox.shrink();
                }
                final label = monthly
                    ? DateFormatter.month(points[i].date)
                    : DateFormat('E').format(points[i].date);
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      color: muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touched) => touched
                .map(
                  (s) => LineTooltipItem(
                    CurrencyFormatter.compact(s.y),
                    GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.primary,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primary.withValues(alpha: 0.22),
                  AppColors.primary.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _axisLabel(double value) {
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}k';
    return value.toStringAsFixed(0);
  }
}

class _CategoryBarChart extends StatelessWidget {
  const _CategoryBarChart({
    required this.months,
    required this.rows,
    required this.categories,
  });

  final List<DateTime> months;
  final List<CategoryMonthSales> rows;
  final List<String> categories;

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.mutedText;
    double maxY = 1000;
    final groups = <BarChartGroupData>[];

    for (var i = 0; i < months.length; i++) {
      final key =
          '${months[i].year.toString().padLeft(4, '0')}-${months[i].month.toString().padLeft(2, '0')}';
      var stackFrom = 0.0;
      final stacks = <BarChartRodStackItem>[];
      for (final category in categories) {
        final amount = rows
            .where((r) => r.monthKey == key && r.category == category)
            .fold<double>(0, (sum, r) => sum + r.total);
        stacks.add(
          BarChartRodStackItem(
            stackFrom,
            stackFrom + amount,
            AppColors.categoryColor(category),
          ),
        );
        stackFrom += amount;
      }
      maxY = math.max(maxY, stackFrom);
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: stackFrom == 0 ? 0.08 * maxY : stackFrom,
              rodStackItems: stackFrom == 0
                  ? [
                      BarChartRodStackItem(
                        0,
                        0.08 * maxY,
                        const Color(0xFFEDEDEF),
                      ),
                    ]
                  : stacks,
              width: 18,
              borderRadius: BorderRadius.circular(6),
            ),
          ],
        ),
      );
    }

    return BarChart(
      BarChartData(
        maxY: maxY * 1.15,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: muted.withValues(alpha: 0.18),
            strokeWidth: 1,
            dashArray: [4, 6],
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, meta) => Text(
                value >= 1000
                    ? '${(value / 1000).toStringAsFixed(0)}k'
                    : value.toStringAsFixed(0),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  color: muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.round();
                if (i < 0 || i >= months.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    DateFormatter.month(months[i]),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      color: muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: groups,
      ),
    );
  }
}

class _ProductSaleTile extends StatelessWidget {
  const _ProductSaleTile({required this.item});

  final ProductSalesRank item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailScreen(productId: item.productId),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: item.imagePath != null
                  ? Image.file(
                      File(item.imagePath!),
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 48,
                      height: 48,
                      color: AppColors.primarySoft,
                      child: const Icon(
                        Icons.fastfood_outlined,
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
                    item.productName,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.categoryName,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppColors.mutedText,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              'Sold ${item.totalQuantity}',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: AppColors.mutedText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
