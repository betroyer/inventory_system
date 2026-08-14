import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/daos/sales_dao.dart';
import 'app_providers.dart';

enum ReportPeriod { daily, weekly, monthly }

final reportDataProvider =
    FutureProvider.family<ReportData, ReportPeriod>((ref, period) async {
  ref.watch(salesProvider);
  ref.watch(expensesProvider);

  final salesDao = ref.watch(salesDaoProvider);
  final expensesDao = ref.watch(expensesDaoProvider);
  final now = DateTime.now();

  late DateTime start;
  late DateTime end;
  switch (period) {
    case ReportPeriod.daily:
      start = DateTime(now.year, now.month, now.day);
      end = start.add(const Duration(days: 1));
    case ReportPeriod.weekly:
      start = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday - 1));
      end = start.add(const Duration(days: 7));
    case ReportPeriod.monthly:
      start = DateTime(now.year, now.month, 1);
      end = DateTime(now.year, now.month + 1, 1);
  }

  final summary = await salesDao.getDailySummary(now);
  final expenses = await expensesDao.getTotalExpensesForDateRange(start, end);
  final bestSellers =
      await salesDao.getBestSellers(start: start, end: end, limit: 5);
  final trend = await salesDao.getSalesTrend(start: start, end: end);
  final sales = await salesDao.watchSalesForDateRange(start, end).first;

  var totalSales = 0.0;
  var totalCost = 0.0;
  var totalProfit = 0.0;
  for (final sale in sales) {
    totalSales += sale.totalAmount;
    totalCost += sale.totalCost;
    totalProfit += sale.profit;
  }

  if (period != ReportPeriod.daily) {
    return ReportData(
      totalSales: totalSales,
      totalCost: totalCost,
      grossProfit: totalProfit,
      expenses: expenses,
      netProfit: totalProfit - expenses,
      transactionCount: sales.length,
      bestSellers: bestSellers,
      trend: trend,
    );
  }

  return ReportData(
    totalSales: summary.totalSales,
    totalCost: summary.totalCost,
    grossProfit: summary.totalProfit,
    expenses: expenses,
    netProfit: summary.totalProfit - expenses,
    transactionCount: summary.transactionCount,
    bestSellers: bestSellers,
    trend: trend,
  );
});

class ReportData {
  const ReportData({
    required this.totalSales,
    required this.totalCost,
    required this.grossProfit,
    required this.expenses,
    required this.netProfit,
    required this.transactionCount,
    required this.bestSellers,
    required this.trend,
  });

  final double totalSales;
  final double totalCost;
  final double grossProfit;
  final double expenses;
  final double netProfit;
  final int transactionCount;
  final List<ProductSalesRank> bestSellers;
  final List<SalesTrendPoint> trend;
}
