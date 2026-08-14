import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/app_widgets.dart';
import '../../shared/providers/report_providers.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  ReportPeriod _period = ReportPeriod.daily;

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(reportDataProvider(_period));

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: SegmentedButton<ReportPeriod>(
              segments: const [
                ButtonSegment(value: ReportPeriod.daily, label: Text('Daily')),
                ButtonSegment(value: ReportPeriod.weekly, label: Text('Weekly')),
                ButtonSegment(
                  value: ReportPeriod.monthly,
                  label: Text('Monthly'),
                ),
              ],
              selected: {_period},
              onSelectionChanged: (value) =>
                  setState(() => _period = value.first),
            ),
          ),
          Expanded(
            child: reportAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (data) => RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(reportDataProvider(_period));
                  await ref.read(reportDataProvider(_period).future);
                },
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.4,
                      children: [
                        StatCard(
                          label: 'Sales',
                          value: CurrencyFormatter.format(data.totalSales),
                          icon: Icons.payments_outlined,
                        ),
                        StatCard(
                          label: 'Gross Profit',
                          value: CurrencyFormatter.format(data.grossProfit),
                          icon: Icons.trending_up_outlined,
                        ),
                        StatCard(
                          label: 'Expenses',
                          value: CurrencyFormatter.format(data.expenses),
                          icon: Icons.receipt_long_outlined,
                        ),
                        StatCard(
                          label: 'Net Profit',
                          value: CurrencyFormatter.format(data.netProfit),
                          icon: Icons.account_balance_wallet_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AppCard(
                      child: Text('Transactions: ${data.transactionCount}'),
                    ),
                    const SizedBox(height: 24),
                    const SectionHeader(title: 'Sales Trend'),
                    const SizedBox(height: 12),
                    if (data.trend.isEmpty)
                      const AppCard(child: Text('No sales data yet.'))
                    else
                      AppCard(
                        child: SizedBox(
                          height: 200,
                          child: LineChart(
                            LineChartData(
                              gridData: const FlGridData(show: false),
                              titlesData: const FlTitlesData(show: false),
                              borderData: FlBorderData(show: false),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: data.trend
                                      .asMap()
                                      .entries
                                      .map(
                                        (e) => FlSpot(
                                          e.key.toDouble(),
                                          e.value.total,
                                        ),
                                      )
                                      .toList(),
                                  isCurved: true,
                                  dotData: const FlDotData(show: false),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    const SectionHeader(title: 'Best Sellers'),
                    const SizedBox(height: 12),
                    if (data.bestSellers.isEmpty)
                      const AppCard(child: Text('No sales yet.'))
                    else
                      ...data.bestSellers.map(
                        (item) => AppCard(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Expanded(child: Text(item.productName)),
                              Text('${item.totalQuantity} sold'),
                              const SizedBox(width: 12),
                              Text(CurrencyFormatter.format(item.totalValue)),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
