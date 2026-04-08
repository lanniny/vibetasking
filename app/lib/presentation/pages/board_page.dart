import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vibetasking/data/database/database.dart';
import 'package:vibetasking/core/theme/app_theme.dart';
import 'package:vibetasking/presentation/blocs/task/task_bloc.dart';
import 'package:vibetasking/presentation/blocs/task/task_event.dart';
import 'package:vibetasking/presentation/blocs/task/task_state.dart';
import 'package:vibetasking/presentation/widgets/common/task_card.dart';
import 'package:vibetasking/presentation/widgets/common/quick_add_dialog.dart';

class BoardPage extends StatelessWidget {
  const BoardPage({super.key});

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
            // #16 进度统计栏
            _ProgressBar(state: state),
            const Divider(height: 1),

            // 看板列
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BoardColumn(
                    title: '待办',
                    status: 'todo',
                    tasks: state.todoTasks,
                    color: const Color(0xFF6366F1),
                  ),
                  _BoardColumn(
                    title: '进行中',
                    status: 'in_progress',
                    tasks: state.inProgressTasks,
                    color: const Color(0xFFF97316),
                  ),
                  _BoardColumn(
                    title: '已完成',
                    status: 'done',
                    tasks: state.doneTasks,
                    color: const Color(0xFF22C55E),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final TaskState state;
  const _ProgressBar({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rate = state.completionRate;
    final pct = (rate * 100).toStringAsFixed(0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text('${state.totalCount} 个任务', style: theme.textTheme.bodySmall),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: rate,
                minHeight: 6,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text('$pct% 完成',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              )),
        ],
      ),
    );
  }
}

class _BoardColumn extends StatelessWidget {
  final String title;
  final String status;
  final List<Task> tasks;
  final Color color;

  const _BoardColumn({
    required this.title,
    required this.status,
    required this.tasks,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: DragTarget<Task>(
        onAcceptWithDetails: (details) {
          context.read<TaskBloc>().add(
                UpdateTaskStatus(taskId: details.data.id, newStatus: status),
              );
        },
        builder: (context, candidateData, rejectedData) {
          final isHovering = candidateData.isNotEmpty;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isHovering
                  ? color.withValues(alpha: 0.08)
                  : theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: isHovering
                  ? Border.all(color: color.withValues(alpha: 0.3), width: 2)
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 列标题 + 添加按钮
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        title,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${tasks.length}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      const Spacer(),
                      // #2 快速添加按钮
                      IconButton(
                        icon: const Icon(Icons.add, size: 18),
                        onPressed: () => QuickAddDialog.show(
                          context,
                          initialStatus: status,
                        ),
                        tooltip: '添加任务',
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),

                // 任务卡片列表
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      return Draggable<Task>(
                        data: task,
                        feedback: Material(
                          elevation: 8,
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 280,
                            child: TaskCard(task: task),
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.3,
                          child: TaskCard(task: task),
                        ),
                        child: TaskCard(
                          task: task,
                          onStatusChanged: (newStatus) {
                            context.read<TaskBloc>().add(
                                  UpdateTaskStatus(
                                    taskId: task.id,
                                    newStatus: newStatus,
                                  ),
                                );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
