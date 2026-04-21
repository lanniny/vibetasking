// Copyright (c) 2026 lanniny. All rights reserved.
// Licensed under the MIT License. See LICENSE file in the project root.

import 'package:equatable/equatable.dart';
import 'package:vibetasking/data/database/database.dart';

class BillState extends Equatable {
  final List<Bill> bills;
  final List<BillCategory> categories;
  final DateTime selectedMonth;
  final bool isLoading;

  const BillState({
    this.bills = const [],
    this.categories = const [],
    required this.selectedMonth,
    this.isLoading = false,
  });

  BillState copyWith({
    List<Bill>? bills,
    List<BillCategory>? categories,
    DateTime? selectedMonth,
    bool? isLoading,
  }) {
    return BillState(
      bills: bills ?? this.bills,
      categories: categories ?? this.categories,
      selectedMonth: selectedMonth ?? this.selectedMonth,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  /// 当月账单
  List<Bill> get monthBills {
    return bills.where((b) {
      return b.date.year == selectedMonth.year &&
          b.date.month == selectedMonth.month;
    }).toList();
  }

  /// 当月总收入
  double get monthIncome => monthBills
      .where((b) => b.type == 'income')
      .fold(0.0, (sum, b) => sum + b.amount);

  /// 当月总支出
  double get monthExpense => monthBills
      .where((b) => b.type == 'expense')
      .fold(0.0, (sum, b) => sum + b.amount);

  /// 当月余额
  double get monthBalance => monthIncome - monthExpense;

  /// 按类别分组统计（当月）
  Map<int, double> get categoryTotals {
    final map = <int, double>{};
    for (final bill in monthBills) {
      if (bill.categoryId != null) {
        map[bill.categoryId!] = (map[bill.categoryId!] ?? 0) + bill.amount;
      }
    }
    return map;
  }

  /// 按日分组统计（当月）
  Map<int, Map<String, double>> get dailyTotals {
    final map = <int, Map<String, double>>{};
    for (final bill in monthBills) {
      final day = bill.date.day;
      map.putIfAbsent(day, () => {'income': 0, 'expense': 0});
      map[day]![bill.type] = (map[day]![bill.type] ?? 0) + bill.amount;
    }
    return map;
  }

  /// 最近 6 个月的月度汇总
  List<MonthSummary> get recentMonthSummaries {
    final results = <MonthSummary>[];
    for (var i = 5; i >= 0; i--) {
      final month = DateTime(selectedMonth.year, selectedMonth.month - i, 1);
      final monthBillsForMonth = bills.where((b) {
        return b.date.year == month.year && b.date.month == month.month;
      });
      final income = monthBillsForMonth
          .where((b) => b.type == 'income')
          .fold(0.0, (sum, b) => sum + b.amount);
      final expense = monthBillsForMonth
          .where((b) => b.type == 'expense')
          .fold(0.0, (sum, b) => sum + b.amount);
      results.add(MonthSummary(month: month, income: income, expense: expense));
    }
    return results;
  }

  /// 查找类别名称
  String categoryName(int? categoryId) {
    if (categoryId == null) return '未分类';
    final cat = categories.where((c) => c.id == categoryId);
    return cat.isNotEmpty ? cat.first.name : '未分类';
  }

  /// 查找类别图标
  String categoryIcon(int? categoryId) {
    if (categoryId == null) return '📦';
    final cat = categories.where((c) => c.id == categoryId);
    return cat.isNotEmpty ? cat.first.icon : '📦';
  }

  /// 查找类别颜色
  String categoryColor(int? categoryId) {
    if (categoryId == null) return '#6B7280';
    final cat = categories.where((c) => c.id == categoryId);
    return cat.isNotEmpty ? cat.first.color : '#6B7280';
  }

  @override
  List<Object?> get props => [bills, categories, selectedMonth, isLoading];
}

class MonthSummary {
  final DateTime month;
  final double income;
  final double expense;

  const MonthSummary({
    required this.month,
    required this.income,
    required this.expense,
  });

  double get balance => income - expense;
}
