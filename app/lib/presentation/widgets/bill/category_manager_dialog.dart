// Copyright (c) 2026 lanniny. All rights reserved.
// Licensed under the MIT License. See LICENSE file in the project root.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vibetasking/presentation/blocs/bill/bill_bloc.dart';
import 'package:vibetasking/presentation/blocs/bill/bill_event.dart';
import 'package:vibetasking/presentation/blocs/bill/bill_state.dart';

class CategoryManagerDialog extends StatefulWidget {
  const CategoryManagerDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<BillBloc>(),
        child: const CategoryManagerDialog(),
      ),
    );
  }

  @override
  State<CategoryManagerDialog> createState() => _CategoryManagerDialogState();
}

class _CategoryManagerDialogState extends State<CategoryManagerDialog>
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
    return BlocBuilder<BillBloc, BillState>(
      builder: (context, state) {
        final expenseCats =
            state.categories.where((c) => c.type == 'expense').toList();
        final incomeCats =
            state.categories.where((c) => c.type == 'income').toList();

        return AlertDialog(
          title: const Text('管理类别'),
          content: SizedBox(
            width: 400,
            height: 400,
            child: Column(
              children: [
                TabBar(
                  controller: _tabCtrl,
                  tabs: [
                    Tab(text: '支出类别 (${expenseCats.length})'),
                    Tab(text: '收入类别 (${incomeCats.length})'),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _buildCategoryList(expenseCats, 'expense'),
                      _buildCategoryList(incomeCats, 'income'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryList(
      List<dynamic> categories, String type) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: categories.length,
            itemBuilder: (context, i) {
              final cat = categories[i];
              return ListTile(
                leading: Text(cat.icon, style: const TextStyle(fontSize: 24)),
                title: Text(cat.name),
                trailing: cat.isDefault
                    ? const Chip(label: Text('默认'))
                    : IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.red, size: 20),
                        onPressed: () => _confirmDelete(cat.id, cat.name),
                      ),
              );
            },
          ),
        ),
        const Divider(),
        TextButton.icon(
          onPressed: () => _showAddCategory(type),
          icon: const Icon(Icons.add),
          label: const Text('新增类别'),
        ),
      ],
    );
  }

  void _confirmDelete(int id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除类别"$name"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              context.read<BillBloc>().add(DeleteCategory(id));
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showAddCategory(String type) {
    final nameCtrl = TextEditingController();
    final iconCtrl = TextEditingController(text: '📦');
    String selectedColor = '#6366F1';

    final colors = [
      '#EF4444', '#F59E0B', '#10B981', '#3B82F6',
      '#6366F1', '#8B5CF6', '#EC4899', '#14B8A6',
      '#F97316', '#6B7280',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInnerState) => AlertDialog(
          title: Text('新增${type == 'expense' ? '支出' : '收入'}类别'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: '类别名称',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: iconCtrl,
                decoration: const InputDecoration(
                  labelText: '图标 (emoji)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: colors.map((c) {
                  final color = _parseColor(c);
                  final isSelected = c == selectedColor;
                  return GestureDetector(
                    onTap: () => setInnerState(() => selectedColor = c),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected
                            ? Border.all(width: 3, color: Colors.white)
                            : null,
                        boxShadow: isSelected
                            ? [BoxShadow(color: color, blurRadius: 8)]
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                context.read<BillBloc>().add(AddCategory(
                      name: nameCtrl.text.trim(),
                      icon: iconCtrl.text.trim().isEmpty
                          ? '📦'
                          : iconCtrl.text.trim(),
                      type: type,
                      color: selectedColor,
                    ));
                Navigator.pop(ctx);
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
  }

  static Color _parseColor(String hex) {
    final code = hex.replaceFirst('#', '');
    return Color(int.parse('FF$code', radix: 16));
  }
}
