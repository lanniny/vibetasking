import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:vibetasking/core/theme/app_theme.dart';
import 'package:vibetasking/data/database/database.dart';
import 'package:vibetasking/presentation/blocs/task/task_bloc.dart';
import 'package:vibetasking/presentation/blocs/task/task_event.dart';

/// 任务详情/编辑对话框 — 解决 CRITICAL #1
class TaskDetailDialog extends StatefulWidget {
  final Task task;

  const TaskDetailDialog({super.key, required this.task});

  static Future<void> show(BuildContext context, Task task) {
    return showDialog(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<TaskBloc>(),
        child: TaskDetailDialog(task: task),
      ),
    );
  }

  @override
  State<TaskDetailDialog> createState() => _TaskDetailDialogState();
}

class _TaskDetailDialogState extends State<TaskDetailDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late String _status;
  late String _priority;
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.task.title);
    _descCtrl = TextEditingController(text: widget.task.description ?? '');
    _status = widget.task.status;
    _priority = widget.task.priority;
    _dueDate = widget.task.dueDate;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _save() {
    context.read<TaskBloc>().add(EditTask(
          taskId: widget.task.id,
          title: _titleCtrl.text,
          description: _descCtrl.text.isEmpty ? null : _descCtrl.text,
          status: _status,
          priority: _priority,
          dueDate: _dueDate,
          clearDueDate: _dueDate == null && widget.task.dueDate != null,
        ));
    Navigator.pop(context);
  }

  void _delete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除任务「${widget.task.title}」吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              context.read<TaskBloc>().add(DeleteTask(taskId: widget.task.id));
              Navigator.pop(ctx); // 关闭确认框
              Navigator.pop(context); // 关闭详情框
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题栏
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppTheme.priorityColor(_priority),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('编辑任务', style: theme.textTheme.titleLarge),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: _delete,
                    tooltip: '删除任务',
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 标题
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: '任务标题'),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),

              // 描述
              TextField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: '描述（支持 Markdown）',
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                minLines: 2,
              ),
              const SizedBox(height: 16),

              // 属性行
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  // 状态
                  _ChipDropdown(
                    label: '状态',
                    value: _status,
                    items: const {
                      'todo': '待办',
                      'in_progress': '进行中',
                      'done': '已完成',
                    },
                    onChanged: (v) => setState(() => _status = v),
                  ),
                  // 优先级
                  _ChipDropdown(
                    label: '优先级',
                    value: _priority,
                    items: const {
                      'urgent': '紧急',
                      'high': '高',
                      'medium': '中',
                      'low': '低',
                    },
                    color: AppTheme.priorityColor(_priority),
                    onChanged: (v) => setState(() => _priority = v),
                  ),
                  // 截止日期
                  ActionChip(
                    avatar: Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: _dueDate != null &&
                              _dueDate!.isBefore(DateTime.now())
                          ? Colors.red
                          : null,
                    ),
                    label: Text(_dueDate != null
                        ? DateFormat('yyyy-MM-dd').format(_dueDate!)
                        : '设置截止日期'),
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _dueDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (date != null) setState(() => _dueDate = date);
                    },
                  ),
                  if (_dueDate != null)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () => setState(() => _dueDate = null),
                      tooltip: '清除日期',
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // 创建时间
              Text(
                '创建于 ${DateFormat('yyyy-MM-dd HH:mm').format(widget.task.createdAt)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),

              const Spacer(),

              // 操作按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('保存'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipDropdown extends StatelessWidget {
  final String label;
  final String value;
  final Map<String, String> items;
  final Color? color;
  final ValueChanged<String> onChanged;

  const _ChipDropdown({
    required this.label,
    required this.value,
    required this.items,
    this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      initialValue: value,
      onSelected: onChanged,
      itemBuilder: (_) => items.entries
          .map((e) => PopupMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
      child: Chip(
        label: Text('$label: ${items[value] ?? value}'),
        backgroundColor: color?.withValues(alpha: 0.12),
        labelStyle: TextStyle(color: color),
      ),
    );
  }
}
