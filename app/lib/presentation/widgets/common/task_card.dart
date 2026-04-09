import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vibetasking/data/database/database.dart';
import 'package:vibetasking/core/theme/app_theme.dart';
import 'package:vibetasking/presentation/widgets/common/task_detail_dialog.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final List<String> tags;
  final VoidCallback? onTap;
  final ValueChanged<String>? onStatusChanged;

  const TaskCard({
    super.key,
    required this.task,
    this.tags = const [],
    this.onTap,
    this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final priorityColor = AppTheme.priorityColor(task.priority);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap ?? () => TaskDetailDialog.show(context, task),
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: priorityColor, width: 4)),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题行
              Row(
                children: [
                  Expanded(
                    child: Text(
                      task.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        decoration: task.status == 'done'
                            ? TextDecoration.lineThrough
                            : null,
                        color: task.status == 'done'
                            ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                            : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _PriorityChip(priority: task.priority),
                ],
              ),

              // 时间段显示
              if (task.startTime != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 13,
                        color: theme.colorScheme.primary.withValues(alpha: 0.7)),
                    const SizedBox(width: 4),
                    Text(
                      _formatTimeRange(task.startTime!, task.endTime),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],

              // #10 描述预览
              if (task.description != null && task.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  task.description!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // 标签展示
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  children: tags
                      .map((t) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              t,
                              style: TextStyle(
                                fontSize: 10,
                                color: theme.colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ],

              const SizedBox(height: 8),

              // 底部信息
              Row(
                children: [
                  if (task.dueDate != null) ...[
                    Icon(Icons.schedule,
                        size: 14,
                        color: _isOverdue(task.dueDate!)
                            ? Colors.red
                            : theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('MM/dd').format(task.dueDate!),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _isOverdue(task.dueDate!)
                            ? Colors.red
                            : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  const Spacer(),
                  _StatusDropdown(
                    status: task.status,
                    onChanged: onStatusChanged,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isOverdue(DateTime date) => date.isBefore(DateTime.now());

  String _formatTimeRange(DateTime start, DateTime? end) {
    final sf = '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
    if (end == null) return sf;
    final ef = '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
    return '$sf - $ef';
  }
}

class _PriorityChip extends StatelessWidget {
  final String priority;
  const _PriorityChip({required this.priority});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.priorityColor(priority).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        AppTheme.priorityLabel(priority),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppTheme.priorityColor(priority),
        ),
      ),
    );
  }
}

class _StatusDropdown extends StatelessWidget {
  final String status;
  final ValueChanged<String>? onChanged;
  const _StatusDropdown({required this.status, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      initialValue: status,
      onSelected: onChanged,
      itemBuilder: (_) => [
        _item('todo', '待办'),
        _item('in_progress', '进行中'),
        _item('done', '已完成'),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          AppTheme.statusLabel(status),
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }

  PopupMenuItem<String> _item(String value, String label) =>
      PopupMenuItem(value: value, child: Text(label));
}
