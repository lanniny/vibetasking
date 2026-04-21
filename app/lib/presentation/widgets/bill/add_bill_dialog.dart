// Copyright (c) 2026 lanniny. All rights reserved.
// Licensed under the MIT License. See LICENSE file in the project root.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:vibetasking/data/database/database.dart';
import 'package:vibetasking/presentation/blocs/bill/bill_bloc.dart';
import 'package:vibetasking/presentation/blocs/bill/bill_event.dart';
import 'package:vibetasking/presentation/blocs/bill/bill_state.dart';
import 'package:vibetasking/presentation/blocs/task/task_bloc.dart';
import 'package:vibetasking/presentation/blocs/task/task_state.dart';

class AddBillDialog extends StatefulWidget {
  final Bill? bill; // null = add, non-null = edit

  const AddBillDialog({super.key, this.bill});

  static Future<void> show(BuildContext context, {Bill? bill}) {
    return showDialog(
      context: context,
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: context.read<BillBloc>()),
          BlocProvider.value(value: context.read<TaskBloc>()),
        ],
        child: AddBillDialog(bill: bill),
      ),
    );
  }

  @override
  State<AddBillDialog> createState() => _AddBillDialogState();
}

class _AddBillDialogState extends State<AddBillDialog> {
  late String _type;
  late TextEditingController _amountCtrl;
  late TextEditingController _descCtrl;
  int? _categoryId;
  int? _taskId;
  late DateTime _date;

  bool get isEdit => widget.bill != null;

  @override
  void initState() {
    super.initState();
    _type = widget.bill?.type ?? 'expense';
    _amountCtrl = TextEditingController(
      text: widget.bill != null ? widget.bill!.amount.toStringAsFixed(2) : '',
    );
    _descCtrl = TextEditingController(text: widget.bill?.description ?? '');
    _categoryId = widget.bill?.categoryId;
    _taskId = widget.bill?.taskId;
    _date = widget.bill?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<BillBloc, BillState>(
      builder: (context, billState) {
        final categories =
            billState.categories.where((c) => c.type == _type).toList();

        return AlertDialog(
          title: Text(isEdit ? '编辑账单' : '新增账单'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 收支类型
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'expense',
                        label: Text('支出'),
                        icon: Icon(Icons.arrow_downward, color: Colors.red),
                      ),
                      ButtonSegment(
                        value: 'income',
                        label: Text('收入'),
                        icon: Icon(Icons.arrow_upward, color: Colors.green),
                      ),
                    ],
                    selected: {_type},
                    onSelectionChanged: (v) => setState(() {
                      _type = v.first;
                      _categoryId = null;
                    }),
                  ),
                  const SizedBox(height: 16),

                  // 金额
                  TextField(
                    controller: _amountCtrl,
                    decoration: const InputDecoration(
                      labelText: '金额',
                      prefixText: '¥ ',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),

                  // 类别选择
                  Text('类别', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categories.map((cat) {
                      final selected = _categoryId == cat.id;
                      return ChoiceChip(
                        label: Text('${cat.icon} ${cat.name}'),
                        selected: selected,
                        onSelected: (_) =>
                            setState(() => _categoryId = cat.id),
                        selectedColor: _parseColor(cat.color).withAlpha(50),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // 日期
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today),
                    title: Text(DateFormat('yyyy-MM-dd').format(_date)),
                    subtitle: const Text('点击修改日期'),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => _date = picked);
                    },
                  ),

                  // 备注
                  TextField(
                    controller: _descCtrl,
                    decoration: const InputDecoration(
                      labelText: '备注（可选）',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),

                  // 关联任务（可选）
                  BlocBuilder<TaskBloc, TaskState>(
                    builder: (context, taskState) {
                      final allTasks = taskState.topLevelTasks;
                      if (allTasks.isEmpty) return const SizedBox.shrink();
                      return DropdownButtonFormField<int?>(
                        value: _taskId,
                        decoration: const InputDecoration(
                          labelText: '关联任务（可选）',
                          border: OutlineInputBorder(),
                        ),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('不关联'),
                          ),
                          ...allTasks.map((t) => DropdownMenuItem(
                                value: t.id,
                                child: Text(
                                  t.title,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )),
                        ],
                        onChanged: (v) => setState(() => _taskId = v),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: _save,
              child: Text(isEdit ? '保存' : '添加'),
            ),
          ],
        );
      },
    );
  }

  void _save() {
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效金额')),
      );
      return;
    }

    final bloc = context.read<BillBloc>();
    if (isEdit) {
      bloc.add(EditBill(
        id: widget.bill!.id,
        amount: amount,
        type: _type,
        categoryId: _categoryId,
        taskId: _taskId,
        description: _descCtrl.text.isEmpty ? null : _descCtrl.text,
        date: _date,
      ));
    } else {
      bloc.add(AddBill(
        amount: amount,
        type: _type,
        categoryId: _categoryId,
        taskId: _taskId,
        description: _descCtrl.text.isEmpty ? null : _descCtrl.text,
        date: _date,
      ));
    }
    Navigator.pop(context);
  }

  static Color _parseColor(String hex) {
    final code = hex.replaceFirst('#', '');
    return Color(int.parse('FF$code', radix: 16));
  }
}
