import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:vibetasking/core/theme/app_theme.dart';
import 'package:vibetasking/data/database/database.dart';
import 'package:vibetasking/presentation/blocs/task/task_bloc.dart';
import 'package:vibetasking/presentation/blocs/task/task_state.dart';
import 'package:vibetasking/presentation/widgets/common/task_detail_dialog.dart';

/// 任务时间线视图 — 按日期展示任务的简化甘特图
class TimelinePage extends StatefulWidget {
  const TimelinePage({super.key});

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> {
  DateTime _selectedDate = DateTime.now();

  void _changeDate(int days) {
    setState(() => _selectedDate = _selectedDate.add(Duration(days: days)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<TaskBloc, TaskState>(
      builder: (context, state) {
        // 收集有日期的任务，按日期分组
        final tasksByDate = <String, List<Task>>{};
        for (final t in state.topLevelTasks) {
          final date = t.startTime ?? t.dueDate;
          if (date != null) {
            final key = DateFormat('yyyy-MM-dd').format(date);
            tasksByDate.putIfAbsent(key, () => []).add(t);
          }
        }
        // 无日期的任务
        final undated = state.topLevelTasks
            .where((t) => t.startTime == null && t.dueDate == null)
            .toList();

        // 生成一周的日期
        final startOfWeek = _selectedDate.subtract(
            Duration(days: _selectedDate.weekday - 1));
        final weekDates =
            List.generate(7, (i) => startOfWeek.add(Duration(days: i)));

        return Column(
          children: [
            // 周导航栏
            _WeekNavigator(
              selectedDate: _selectedDate,
              onPrevWeek: () => _changeDate(-7),
              onNextWeek: () => _changeDate(7),
              onToday: () => setState(() => _selectedDate = DateTime.now()),
            ),
            const Divider(height: 1),

            // 时间线主体
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 时间轴标尺（小时）
                  SizedBox(
                    width: 50,
                    child: _TimeRuler(),
                  ),
                  const VerticalDivider(width: 1),

                  // 每天一列
                  ...weekDates.map((date) {
                    final key = DateFormat('yyyy-MM-dd').format(date);
                    final dayTasks = tasksByDate[key] ?? [];
                    final isToday = _isSameDay(date, DateTime.now());
                    final isSelected = _isSameDay(date, _selectedDate);

                    return Expanded(
                      child: _DayColumn(
                        date: date,
                        tasks: dayTasks,
                        isToday: isToday,
                        isSelected: isSelected,
                        onTap: () => setState(() => _selectedDate = date),
                      ),
                    );
                  }),
                ],
              ),
            ),

            // 无日期任务提示
            if (undated.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                child: Row(
                  children: [
                    Icon(Icons.event_busy, size: 16,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                    const SizedBox(width: 8),
                    Text(
                      '${undated.length} 个任务未安排日期',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ── 周导航栏 ──

class _WeekNavigator extends StatelessWidget {
  final DateTime selectedDate;
  final VoidCallback onPrevWeek;
  final VoidCallback onNextWeek;
  final VoidCallback onToday;

  const _WeekNavigator({
    required this.selectedDate,
    required this.onPrevWeek,
    required this.onNextWeek,
    required this.onToday,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weekStart = selectedDate.subtract(
        Duration(days: selectedDate.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrevWeek,
            tooltip: '上一周',
            visualDensity: VisualDensity.compact,
          ),
          Text(
            '${DateFormat('MM/dd').format(weekStart)} - ${DateFormat('MM/dd').format(weekEnd)}',
            style: theme.textTheme.titleSmall,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: onNextWeek,
            tooltip: '下一周',
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: onToday,
            icon: const Icon(Icons.today, size: 16),
            label: const Text('今天'),
          ),
          const Spacer(),
          Icon(Icons.timeline, size: 18,
              color: theme.colorScheme.primary.withValues(alpha: 0.5)),
          const SizedBox(width: 4),
          Text('时间线',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
              )),
        ],
      ),
    );
  }
}

// ── 时间轴标尺 ──

class _TimeRuler extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView.builder(
      itemCount: 24,
      itemBuilder: (context, hour) {
        return SizedBox(
          height: 60,
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 8, top: 2),
              child: Text(
                '${hour.toString().padLeft(2, '0')}:00',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── 日列 ──

class _DayColumn extends StatelessWidget {
  final DateTime date;
  final List<Task> tasks;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  const _DayColumn({
    required this.date,
    required this.tasks,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  static const _weekDays = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 分为有时间和无时间的任务
    final scheduled = tasks.where((t) => t.startTime != null).toList();
    final unscheduled = tasks.where((t) => t.startTime == null).toList();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isToday
              ? theme.colorScheme.primary.withValues(alpha: 0.04)
              : null,
          border: isSelected
              ? Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2))
              : null,
        ),
        child: Column(
          children: [
            // 日期头
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: isToday
                    ? theme.colorScheme.primary.withValues(alpha: 0.1)
                    : null,
              ),
              child: Column(
                children: [
                  Text(
                    _weekDays[date.weekday],
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isToday ? theme.colorScheme.primary : null,
                      fontWeight: isToday ? FontWeight.w600 : null,
                    ),
                  ),
                  Text(
                    '${date.day}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: isToday ? theme.colorScheme.primary : null,
                      fontWeight: isToday ? FontWeight.bold : null,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // 时间格中的任务
            Expanded(
              child: Stack(
                children: [
                  // 24小时网格线
                  ...List.generate(24, (i) => Positioned(
                    top: i * 60.0,
                    left: 0, right: 0,
                    child: Divider(
                      height: 1,
                      color: theme.dividerColor.withValues(alpha: 0.1),
                    ),
                  )),

                  // 有时间的任务块
                  ...scheduled.map((task) => _TimeBlock(task: task)),

                  // 无时间的任务（堆在顶部）
                  if (unscheduled.isNotEmpty)
                    Positioned(
                      top: 4,
                      left: 2, right: 2,
                      child: Column(
                        children: unscheduled.map((t) => _MiniTaskChip(task: t)).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 时间块（有 startTime 的任务）──

class _TimeBlock extends StatelessWidget {
  final Task task;
  const _TimeBlock({required this.task});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final start = task.startTime!;
    final end = task.endTime ?? start.add(const Duration(hours: 1));
    final topOffset = (start.hour * 60 + start.minute).toDouble();
    final duration = end.difference(start).inMinutes.toDouble();
    final height = duration.clamp(20, 300).toDouble();
    final color = AppTheme.priorityColor(task.priority);

    return Positioned(
      top: topOffset,
      left: 2,
      right: 2,
      height: height,
      child: GestureDetector(
        onTap: () => TaskDetailDialog.show(context, task),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            border: Border(left: BorderSide(color: color, width: 3)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                maxLines: height > 40 ? 2 : 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (height > 30)
                Text(
                  '${_fmt(start)} - ${_fmt(end)}',
                  style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.7)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

// ── 迷你任务标签（无时间的任务）──

class _MiniTaskChip extends StatelessWidget {
  final Task task;
  const _MiniTaskChip({required this.task});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.priorityColor(task.priority);
    return GestureDetector(
      onTap: () => TaskDetailDialog.show(context, task),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          task.title,
          style: TextStyle(fontSize: 10, color: color),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
