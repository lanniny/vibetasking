import 'package:equatable/equatable.dart';
import 'package:vibetasking/data/database/database.dart';

enum TaskStatus { initial, loading, loaded, error }

class TaskState extends Equatable {
  final TaskStatus status;
  final List<Task> tasks;
  final String? errorMessage;
  final String? statusFilter;
  final String? priorityFilter;
  final String sortBy;

  const TaskState({
    this.status = TaskStatus.initial,
    this.tasks = const [],
    this.errorMessage,
    this.statusFilter,
    this.priorityFilter,
    this.sortBy = 'created_at',
  });

  TaskState copyWith({
    TaskStatus? status,
    List<Task>? tasks,
    String? errorMessage,
    String? statusFilter,
    String? priorityFilter,
    String? sortBy,
  }) {
    return TaskState(
      status: status ?? this.status,
      tasks: tasks ?? this.tasks,
      errorMessage: errorMessage ?? this.errorMessage,
      statusFilter: statusFilter,
      priorityFilter: priorityFilter,
      sortBy: sortBy ?? this.sortBy,
    );
  }

  /// 按状态分组（看板用）
  List<Task> get todoTasks =>
      tasks.where((t) => t.status == 'todo').toList();

  List<Task> get inProgressTasks =>
      tasks.where((t) => t.status == 'in_progress').toList();

  List<Task> get doneTasks =>
      tasks.where((t) => t.status == 'done').toList();

  @override
  List<Object?> get props =>
      [status, tasks, errorMessage, statusFilter, priorityFilter, sortBy];
}
