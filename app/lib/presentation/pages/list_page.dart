import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:vibetasking/core/theme/app_theme.dart';
import 'package:vibetasking/presentation/blocs/task/task_bloc.dart';
import 'package:vibetasking/presentation/blocs/task/task_event.dart';
import 'package:vibetasking/presentation/blocs/task/task_state.dart';

class ListPage extends StatelessWidget {
  const ListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<TaskBloc, TaskState>(
      builder: (context, state) {
        if (state.status == TaskStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            // 工具栏：排序 + 筛选
            _Toolbar(state: state),
            const Divider(height: 1),

            // 任务列表
            Expanded(
              child: state.tasks.isEmpty
                  ? Center(
                      child: Text(
                        '暂无任务，去聊天页面创建吧 ✨',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: state.tasks.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                      itemBuilder: (context, index) {
                        final task = state.tasks[index];
                        return _TaskRow(
                          title: task.title,
                          status: task.status,
                          priority: task.priority,
                          dueDate: task.dueDate,
                          onStatusChanged: (s) => context.read<TaskBloc>().add(
                                UpdateTaskStatus(
                                    taskId: task.id, newStatus: s),
                              ),
                          onDelete: () => context
                              .read<TaskBloc>()
                              .add(DeleteTask(taskId: task.id)),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _Toolbar extends StatelessWidget {
  final TaskState state;
  const _Toolbar({required this.state});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // 排序
          const Icon(Icons.sort, size: 18),
          const SizedBox(width: 4),
          SegmentedButton<String>(
            selected: {state.sortBy},
            onSelectionChanged: (value) {
              context.read<TaskBloc>().add(FilterTasks(sortBy: value.first));
            },
            segments: const [
              ButtonSegment(value: 'created_at', label: Text('时间')),
              ButtonSegment(value: 'priority', label: Text('优先级')),
              ButtonSegment(value: 'due_date', label: Text('截止日')),
            ],
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              textStyle: WidgetStatePropertyAll(
                Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          const Spacer(),
          Text(
            '${state.tasks.length} 个任务',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
          ),
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  final String title;
  final String status;
  final String priority;
  final DateTime? dueDate;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onDelete;

  const _TaskRow({
    required this.title,
    required this.status,
    required this.priority,
    required this.dueDate,
    required this.onStatusChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDone = status == 'done';

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // 状态勾选框
            Checkbox(
              value: isDone,
              onChanged: (v) {
                onStatusChanged(v == true ? 'done' : 'todo');
              },
              activeColor: AppTheme.priorityColor(priority),
            ),

            // 优先级标记
            Container(
              width: 4,
              height: 24,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: AppTheme.priorityColor(priority),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // 标题
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  decoration: isDone ? TextDecoration.lineThrough : null,
                  color: isDone
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                      : null,
                ),
              ),
            ),

            // 截止日期
            if (dueDate != null) ...[
              Text(
                DateFormat('MM/dd').format(dueDate!),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: dueDate!.isBefore(DateTime.now())
                      ? Colors.red
                      : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(width: 8),
            ],

            // 优先级标签
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.priorityColor(priority).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                AppTheme.priorityLabel(priority),
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.priorityColor(priority),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            // 删除按钮
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              onPressed: onDelete,
              tooltip: '删除',
            ),
          ],
        ),
      ),
    );
  }
}
