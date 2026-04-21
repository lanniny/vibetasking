// Copyright (c) 2026 lanniny. All rights reserved.
// Licensed under the MIT License. See LICENSE file in the project root.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:vibetasking/data/database/database.dart';
import 'package:vibetasking/presentation/blocs/bill/bill_bloc.dart';
import 'package:vibetasking/presentation/blocs/bill/bill_event.dart';
import 'package:vibetasking/presentation/blocs/bill/bill_state.dart';
import 'package:vibetasking/presentation/widgets/bill/add_bill_dialog.dart';
import 'package:vibetasking/presentation/widgets/bill/bill_chart.dart';
import 'package:vibetasking/presentation/widgets/bill/category_manager_dialog.dart';

class BillPage extends StatelessWidget {
  const BillPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BillBloc, BillState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        return Column(
          children: [
            _BillHeader(state: state),
            Expanded(
              child: _BillBody(state: state),
            ),
          ],
        );
      },
    );
  }
}

// ── 顶部总览 ──

class _BillHeader extends StatelessWidget {
  final BillState state;
  const _BillHeader({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
      ),
      child: Column(
        children: [
          // 月份切换
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _changeMonth(context, -1),
              ),
              Text(
                DateFormat('yyyy年M月').format(state.selectedMonth),
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _changeMonth(context, 1),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => context.read<BillBloc>().add(
                    FilterBillsByMonth(
                        DateTime(DateTime.now().year, DateTime.now().month))),
                child: const Text('本月'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 收支汇总卡片
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  label: '收入',
                  amount: state.monthIncome,
                  color: Colors.green,
                  icon: Icons.arrow_upward,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryCard(
                  label: '支出',
                  amount: state.monthExpense,
                  color: Colors.red,
                  icon: Icons.arrow_downward,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryCard(
                  label: '结余',
                  amount: state.monthBalance,
                  color: state.monthBalance >= 0
                      ? Colors.blue
                      : Colors.orange,
                  icon: Icons.account_balance_wallet,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _changeMonth(BuildContext context, int delta) {
    final cur = state.selectedMonth;
    context.read<BillBloc>().add(
        FilterBillsByMonth(DateTime(cur.year, cur.month + delta)));
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 4),
                Text(label, style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '¥${amount.toStringAsFixed(2)}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 内容区域（Tab: 明细 / 图表） ──

class _BillBody extends StatefulWidget {
  final BillState state;
  const _BillBody({required this.state});

  @override
  State<_BillBody> createState() => _BillBodyState();
}

class _BillBodyState extends State<_BillBody>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        // Tab + 操作按钮
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: TabBar(
                  controller: _tabCtrl,
                  tabs: const [
                    Tab(text: '明细'),
                    Tab(text: '图表'),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.category_outlined),
                tooltip: '管理类别',
                onPressed: () => CategoryManagerDialog.show(context),
              ),
              FilledButton.icon(
                onPressed: () => AddBillDialog.show(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('记一笔'),
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _BillList(state: widget.state),
              _BillCharts(state: widget.state),
            ],
          ),
        ),
      ],
    );
  }
}

// ── 账单明细列表 ──

class _BillList extends StatelessWidget {
  final BillState state;
  const _BillList({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bills = state.monthBills;

    if (bills.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text('本月暂无账单', style: theme.textTheme.bodyLarge),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: () => AddBillDialog.show(context),
              child: const Text('记一笔'),
            ),
          ],
        ),
      );
    }

    // 按日期分组
    final grouped = <String, List<Bill>>{};
    for (final b in bills) {
      final key = DateFormat('MM月dd日 EEEE', 'zh_CN').format(b.date);
      grouped.putIfAbsent(key, () => []).add(b);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: grouped.length,
      itemBuilder: (context, i) {
        final entry = grouped.entries.elementAt(i);
        final dayBills = entry.value;
        final dayIncome = dayBills
            .where((b) => b.type == 'income')
            .fold(0.0, (sum, b) => sum + b.amount);
        final dayExpense = dayBills
            .where((b) => b.type == 'expense')
            .fold(0.0, (sum, b) => sum + b.amount);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 日期头
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Text(entry.key,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (dayIncome > 0)
                    Text('收入 ¥${dayIncome.toStringAsFixed(2)}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.green)),
                  const SizedBox(width: 12),
                  if (dayExpense > 0)
                    Text('支出 ¥${dayExpense.toStringAsFixed(2)}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.red)),
                ],
              ),
            ),
            // 该日账单
            ...dayBills.map((bill) => _BillListItem(bill: bill, state: state)),
            const Divider(),
          ],
        );
      },
    );
  }
}

class _BillListItem extends StatelessWidget {
  final Bill bill;
  final BillState state;
  const _BillListItem({required this.bill, required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isExpense = bill.type == 'expense';
    final color = isExpense ? Colors.red : Colors.green;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _parseColor(state.categoryColor(bill.categoryId))
            .withAlpha(30),
        child: Text(
          state.categoryIcon(bill.categoryId),
          style: const TextStyle(fontSize: 20),
        ),
      ),
      title: Text(
        bill.description?.isNotEmpty == true
            ? bill.description!
            : state.categoryName(bill.categoryId),
      ),
      subtitle: bill.taskId != null
          ? Text('关联任务 #${bill.taskId}',
              style: theme.textTheme.bodySmall)
          : null,
      trailing: Text(
        '${isExpense ? "-" : "+"}¥${bill.amount.toStringAsFixed(2)}',
        style: theme.textTheme.titleSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
      onTap: () => AddBillDialog.show(context, bill: bill),
      onLongPress: () => _confirmDelete(context, bill),
    );
  }

  void _confirmDelete(BuildContext context, Bill bill) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text(
            '确定要删除这笔${bill.type == "expense" ? "支出" : "收入"} ¥${bill.amount.toStringAsFixed(2)} 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              context.read<BillBloc>().add(DeleteBill(bill.id));
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  static Color _parseColor(String hex) {
    final code = hex.replaceFirst('#', '');
    return Color(int.parse('FF$code', radix: 16));
  }
}

// ── 图表页面 ──

class _BillCharts extends StatelessWidget {
  final BillState state;
  const _BillCharts({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 饼图 - 支出分类
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('支出分类',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: ExpensePieChart(state: state),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 柱状图 - 近 6 月收支对比
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('月度收支',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    _LegendDot(color: Colors.green.shade400, label: '收入'),
                    const SizedBox(width: 12),
                    _LegendDot(color: Colors.red.shade400, label: '支出'),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: MonthBarChart(state: state),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 折线图 - 日累积趋势
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('累计趋势',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    _LegendDot(color: Colors.green.shade400, label: '累计收入'),
                    const SizedBox(width: 12),
                    _LegendDot(color: Colors.red.shade400, label: '累计支出'),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: DailyLineChart(state: state),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
