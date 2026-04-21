// Copyright (c) 2026 lanniny. All rights reserved.
// Licensed under the MIT License. See LICENSE file in the project root.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vibetasking/presentation/blocs/bill/bill_state.dart';

/// 支出分类饼图
class ExpensePieChart extends StatelessWidget {
  final BillState state;

  const ExpensePieChart({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expenseBills =
        state.monthBills.where((b) => b.type == 'expense').toList();
    if (expenseBills.isEmpty) {
      return Center(
        child: Text('本月暂无支出', style: theme.textTheme.bodyLarge),
      );
    }

    // 按类别汇总
    final catTotals = <int, double>{};
    for (final b in expenseBills) {
      final cid = b.categoryId ?? -1;
      catTotals[cid] = (catTotals[cid] ?? 0) + b.amount;
    }

    final total = catTotals.values.fold(0.0, (a, b) => a + b);
    final entries = catTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Row(
      children: [
        Expanded(
          child: AspectRatio(
            aspectRatio: 1,
            child: PieChart(
              PieChartData(
                sections: entries.map((e) {
                  final pct = (e.value / total * 100);
                  final color = _parseColor(state.categoryColor(
                      e.key == -1 ? null : e.key));
                  return PieChartSectionData(
                    value: e.value,
                    title: '${pct.toStringAsFixed(1)}%',
                    color: color,
                    radius: 80,
                    titleStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  );
                }).toList(),
                sectionsSpace: 2,
                centerSpaceRadius: 30,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // 图例
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: entries.map((e) {
            final catId = e.key == -1 ? null : e.key;
            final color = _parseColor(state.categoryColor(catId));
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${state.categoryIcon(catId)} ${state.categoryName(catId)}',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '¥${e.value.toStringAsFixed(0)}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// 月度收支柱状图
class MonthBarChart extends StatelessWidget {
  final BillState state;

  const MonthBarChart({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summaries = state.recentMonthSummaries;
    if (summaries.every((s) => s.income == 0 && s.expense == 0)) {
      return Center(
        child: Text('暂无数据', style: theme.textTheme.bodyLarge),
      );
    }

    final maxVal = summaries.fold<double>(
        0,
        (max, s) => [max, s.income, s.expense]
            .reduce((a, b) => a > b ? a : b));

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxVal * 1.2,
        barGroups: summaries.asMap().entries.map((entry) {
          final i = entry.key;
          final s = entry.value;
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: s.income,
                color: Colors.green.shade400,
                width: 14,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
              BarChartRodData(
                toY: s.expense,
                color: Colors.red.shade400,
                width: 14,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= summaries.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    DateFormat('M月').format(summaries[idx].month),
                    style: theme.textTheme.bodySmall,
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();
                return Text(
                  _formatAmount(value),
                  style: theme.textTheme.bodySmall,
                );
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
      ),
    );
  }
}

/// 日趋势折线图
class DailyLineChart extends StatelessWidget {
  final BillState state;

  const DailyLineChart({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dailyTotals = state.dailyTotals;
    if (dailyTotals.isEmpty) {
      return Center(
        child: Text('本月暂无数据', style: theme.textTheme.bodyLarge),
      );
    }

    final daysInMonth = DateUtils.getDaysInMonth(
        state.selectedMonth.year, state.selectedMonth.month);

    final incomeSpots = <FlSpot>[];
    final expenseSpots = <FlSpot>[];
    double cumIncome = 0;
    double cumExpense = 0;

    for (var d = 1; d <= daysInMonth; d++) {
      final dayData = dailyTotals[d];
      cumIncome += dayData?['income'] ?? 0;
      cumExpense += dayData?['expense'] ?? 0;
      incomeSpots.add(FlSpot(d.toDouble(), cumIncome));
      expenseSpots.add(FlSpot(d.toDouble(), cumExpense));
    }

    final maxY = [cumIncome, cumExpense].reduce((a, b) => a > b ? a : b);

    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: incomeSpots,
            isCurved: true,
            color: Colors.green.shade400,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.green.withAlpha(30),
            ),
          ),
          LineChartBarData(
            spots: expenseSpots,
            isCurved: true,
            color: Colors.red.shade400,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.red.withAlpha(30),
            ),
          ),
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 5,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}日',
                  style: theme.textTheme.bodySmall,
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();
                return Text(
                  _formatAmount(value),
                  style: theme.textTheme.bodySmall,
                );
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        maxY: maxY * 1.1,
        minY: 0,
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
      ),
    );
  }
}

String _formatAmount(double value) {
  if (value >= 10000) return '${(value / 10000).toStringAsFixed(1)}万';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
  return value.toStringAsFixed(0);
}

Color _parseColor(String hex) {
  final code = hex.replaceFirst('#', '');
  return Color(int.parse('FF$code', radix: 16));
}
