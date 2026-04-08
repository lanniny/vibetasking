import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:vibetasking/core/theme/app_theme.dart';
import 'package:vibetasking/data/database/database.dart';
import 'package:vibetasking/presentation/blocs/task/task_bloc.dart';
import 'package:vibetasking/presentation/blocs/task/task_event.dart';
import 'package:vibetasking/presentation/blocs/task/task_state.dart';
import 'package:vibetasking/presentation/widgets/common/quick_add_dialog.dart';
import 'package:vibetasking/presentation/widgets/common/task_detail_dialog.dart';

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

        final displayTasks = state.topLevelTasks;

        return Column(
          children: [
            // #7 搜索栏 + #8 筛选
            _Toolbar(state: state),
            const Divider(height: 1),

            // 任务列表
            Expanded(
              child: displayTasks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inbox_outlined,
                              size: 48,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.2)),
                          const SizedBox(height: 12),
                          Text(
                            state.searchQuery.isNotEmpty
                                ? '没有找到匹配的任务'
                                : '暂无任务',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: displayTasks.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                      itemBuilder: (context, index) {
                        final task = displayTasks[index];
                        return _TaskRow(task: task);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _Toolbar extends StatefulWidget {
  final TaskState state;
  const _Toolbar({required this.state});

  @override
  State<_Toolbar> createState() => _ToolbarState();
}

class _ToolbarState extends State<_Toolbar> {
  bool _showSearch = false;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              // 搜索切换
              IconButton(
                icon: Icon(_showSearch ? Icons.close : Icons.search, size: 20),
                onPressed: () {
                  setState(() {
                    _showSearch = !_showSearch;
                    if (!_showSearch) {
                      _searchCtrl.clear();
                      context.read<TaskBloc>().add(const SearchTasks(''));
                    }
                  });
                },
                tooltip: '搜索',
                visualDensity: VisualDensity.compact,
              ),

              if (_showSearch) ...[
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: TextField(
                      controller: _searchCtrl,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: '搜索任务...',
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onChanged: (q) =>
                          context.read<TaskBloc>().add(SearchTasks(q)),
                    ),
                  ),
                ),
              ] else ...[
                // 排序
                const SizedBox(width: 4),
                SegmentedButton<String>(
                  selected: {widget.state.sortBy},
                  onSelectionChanged: (value) {
                    context
                        .read<TaskBloc>()
                        .add(FilterTasks(sortBy: value.first));
                  },
                  segments: const [
                    ButtonSegment(value: 'created_at', label: Text('时间')),
                    ButtonSegment(value: 'priority', label: Text('优先级')),
                    ButtonSegment(value: 'due_date', label: Text('截止日')),
                  ],
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    textStyle: WidgetStatePropertyAll(
                        theme.textTheme.bodySmall),
                  ),
                ),
                const SizedBox(width: 8),

                // #8 状态筛选
                PopupMenuButton<String?>(
                  initialValue: widget.state.statusFilter,
                  onSelected: (v) =>
                      context.read<TaskBloc>().add(FilterTasks(
                            statusFilter: v,
                            sortBy: widget.state.sortBy,
                          )),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: null, child: Text('全部状态')),
                    const PopupMenuItem(value: 'todo', child: Text('待办')),
                    const PopupMenuItem(
                        value: 'in_progress', child: Text('进行中')),
                    const PopupMenuItem(value: 'done', child: Text('已完成')),
                  ],
                  child: Chip(
                    avatar: const Icon(Icons.filter_list, size: 16),
                    label: Text(
                      widget.state.statusFilter != null
                          ? AppTheme.statusLabel(widget.state.statusFilter!)
                          : '筛选',
                      style: const TextStyle(fontSize: 12),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],

              const Spacer(),
              Text(
                '${widget.state.topLevelTasks.length} 个任务',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(width: 8),
              // #2 快速添加
              IconButton.filled(
                onPressed: () => QuickAddDialog.show(context),
                icon: const Icon(Icons.add, size: 18),
                tooltip: '快速创建任务',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  final Task task;
  const _TaskRow({required this.task});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDone = task.status == 'done';

    return Card(
      child: InkWell(
        onTap: () => TaskDetailDialog.show(context, task),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // 状态勾选框
              Checkbox(
                value: isDone,
                onChanged: (v) {
                  context.read<TaskBloc>().add(UpdateTaskStatus(
                      taskId: task.id,
                      newStatus: v == true ? 'done' : 'todo'));
                },
                activeColor: AppTheme.priorityColor(task.priority),
              ),

              // 优先级标记
              Container(
                width: 4,
                height: 24,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: AppTheme.priorityColor(task.priority),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // 标题 + 描述
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        decoration:
                            isDone ? TextDecoration.lineThrough : null,
                        color: isDone
                            ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                            : null,
                      ),
                    ),
                    if (task.description != null &&
                        task.description!.isNotEmpty)
                      Text(
                        task.description!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.4),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),

              // 截止日期
              if (task.dueDate != null) ...[
                Text(
                  DateFormat('MM/dd').format(task.dueDate!),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: task.dueDate!.isBefore(DateTime.now())
                        ? Colors.red
                        : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(width: 8),
              ],

              // 优先级标签
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.priorityColor(task.priority)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  AppTheme.priorityLabel(task.priority),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.priorityColor(task.priority),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              // #6 删除按钮（带确认）
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: () => _confirmDelete(context, task),
                tooltip: '删除',
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Task task) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除「${task.title}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              context.read<TaskBloc>().add(DeleteTask(taskId: task.id));
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
