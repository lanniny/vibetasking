import 'package:equatable/equatable.dart';
import 'package:vibetasking/data/database/database.dart';

enum TaskStatus { initial, loading, loaded, error }

/// Sentinel: 用于区分 "没传" vs "主动传 null 清除筛选"
const _sentinel = '__KEEP__';

class TaskState extends Equatable {
  final TaskStatus status;
  final List<Task> allTasks;
  final Map<int, List<String>> taskTags; // taskId → tag names
  final String? errorMessage;
  final String? statusFilter;
  final String? priorityFilter;
  final String? tagFilter;
  final String sortBy;
  final String searchQuery;

  const TaskState({
    this.status = TaskStatus.initial,
    this.allTasks = const [],
    this.taskTags = const {},
    this.errorMessage,
    this.statusFilter,
    this.priorityFilter,
    this.tagFilter,
    this.sortBy = 'created_at',
    this.searchQuery = '',
  });

  /// 获取任务的标签列表
  List<String> tagsOf(int taskId) => taskTags[taskId] ?? [];

  TaskState copyWith({
    TaskStatus? status,
    List<Task>? allTasks,
    Map<int, List<String>>? taskTags,
    String? errorMessage,
    Object? statusFilter = _sentinel,
    Object? priorityFilter = _sentinel,
    Object? tagFilter = _sentinel,
    String? sortBy,
    String? searchQuery,
  }) {
    return TaskState(
      status: status ?? this.status,
      allTasks: allTasks ?? this.allTasks,
      taskTags: taskTags ?? this.taskTags,
      errorMessage: errorMessage ?? this.errorMessage,
      statusFilter: statusFilter == _sentinel
          ? this.statusFilter
          : statusFilter as String?,
      priorityFilter: priorityFilter == _sentinel
          ? this.priorityFilter
          : priorityFilter as String?,
      tagFilter: tagFilter == _sentinel
          ? this.tagFilter
          : tagFilter as String?,
      sortBy: sortBy ?? this.sortBy,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  /// 应用搜索和筛选后的任务列表
  List<Task> get tasks {
    var result = List<Task>.from(allTasks);

    // 搜索
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      result = result
          .where((t) =>
              t.title.toLowerCase().contains(q) ||
              (t.description?.toLowerCase().contains(q) ?? false))
          .toList();
    }

    // 状态筛选
    if (statusFilter != null && statusFilter!.isNotEmpty) {
      result = result.where((t) => t.status == statusFilter).toList();
    }

    // 优先级筛选
    if (priorityFilter != null && priorityFilter!.isNotEmpty) {
      result = result.where((t) => t.priority == priorityFilter).toList();
    }

    // 排序
    switch (sortBy) {
      case 'priority':
        const order = {'urgent': 0, 'high': 1, 'medium': 2, 'low': 3};
        result.sort((a, b) =>
            (order[a.priority] ?? 2).compareTo(order[b.priority] ?? 2));
        break;
      case 'due_date':
        result.sort((a, b) {
          if (a.dueDate == null && b.dueDate == null) return 0;
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          return a.dueDate!.compareTo(b.dueDate!);
        });
        break;
      default:
        result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return result;
  }

  // 只取顶级任务（parentId == null）
  List<Task> get topLevelTasks =>
      tasks.where((t) => t.parentId == null).toList();

  List<Task> subTasksOf(int parentId) =>
      allTasks.where((t) => t.parentId == parentId).toList();

  List<Task> get todoTasks =>
      topLevelTasks.where((t) => t.status == 'todo').toList();

  List<Task> get inProgressTasks =>
      topLevelTasks.where((t) => t.status == 'in_progress').toList();

  List<Task> get doneTasks =>
      topLevelTasks.where((t) => t.status == 'done').toList();

  // 统计
  int get totalCount => topLevelTasks.length;
  int get doneCount => doneTasks.length;
  double get completionRate =>
      totalCount == 0 ? 0 : doneCount / totalCount;

  @override
  List<Object?> get props => [
        status, allTasks, taskTags, errorMessage, statusFilter,
        priorityFilter, tagFilter, sortBy, searchQuery,
      ];
}
