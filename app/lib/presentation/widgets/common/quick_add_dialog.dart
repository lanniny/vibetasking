import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:vibetasking/core/theme/app_theme.dart';
import 'package:vibetasking/presentation/blocs/task/task_bloc.dart';
import 'package:vibetasking/presentation/blocs/task/task_event.dart';

/// 快速创建任务对话框 — 解决 CRITICAL #2
class QuickAddDialog extends StatefulWidget {
  final String? initialStatus;

  const QuickAddDialog({super.key, this.initialStatus});

  static Future<void> show(BuildContext context, {String? initialStatus}) {
    return showDialog(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<TaskBloc>(),
        child: QuickAddDialog(initialStatus: initialStatus),
      ),
    );
  }

  @override
  State<QuickAddDialog> createState() => _QuickAddDialogState();
}

class _QuickAddDialogState extends State<QuickAddDialog> {
  final _titleCtrl = TextEditingController();
  String _priority = 'medium';
  DateTime? _dueDate;

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;

    context.read<TaskBloc>().add(AddTask(
          title: title,
          priority: _priority,
          dueDate: _dueDate,
        ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('快速创建任务'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题输入
            TextField(
              controller: _titleCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '任务标题...',
                prefixIcon: Icon(Icons.add_task),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),

            // 属性行
            Row(
              children: [
                // 优先级
                ...['low', 'medium', 'high', 'urgent'].map((p) {
                  final isSelected = _priority == p;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(AppTheme.priorityLabel(p)),
                      selected: isSelected,
                      selectedColor: AppTheme.priorityColor(p).withValues(alpha: 0.2),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        color: isSelected
                            ? AppTheme.priorityColor(p)
                            : null,
                      ),
                      onSelected: (_) => setState(() => _priority = p),
                      visualDensity: VisualDensity.compact,
                    ),
                  );
                }),
                const Spacer(),

                // 日期选择
                ActionChip(
                  avatar: const Icon(Icons.calendar_today, size: 16),
                  label: Text(_dueDate != null
                      ? DateFormat('MM/dd').format(_dueDate!)
                      : '截止日期'),
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 1)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) setState(() => _dueDate = date);
                  },
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('创建'),
        ),
      ],
    );
  }
}
