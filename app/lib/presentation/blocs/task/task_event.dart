import 'package:equatable/equatable.dart';

abstract class TaskEvent extends Equatable {
  const TaskEvent();

  @override
  List<Object?> get props => [];
}

class LoadTasks extends TaskEvent {}

class AddTask extends TaskEvent {
  final String title;
  final String? description;
  final String priority;
  final DateTime? dueDate;
  final List<String> tags;
  final int? parentId;

  const AddTask({
    required this.title,
    this.description,
    this.priority = 'medium',
    this.dueDate,
    this.tags = const [],
    this.parentId,
  });

  @override
  List<Object?> get props =>
      [title, description, priority, dueDate, tags, parentId];
}

class UpdateTaskStatus extends TaskEvent {
  final int taskId;
  final String newStatus;

  const UpdateTaskStatus({required this.taskId, required this.newStatus});

  @override
  List<Object?> get props => [taskId, newStatus];
}

class DeleteTask extends TaskEvent {
  final int taskId;

  const DeleteTask({required this.taskId});

  @override
  List<Object?> get props => [taskId];
}

class FilterTasks extends TaskEvent {
  final String? statusFilter;
  final String? priorityFilter;
  final String? tagFilter;
  final String sortBy; // created_at / due_date / priority

  const FilterTasks({
    this.statusFilter,
    this.priorityFilter,
    this.tagFilter,
    this.sortBy = 'created_at',
  });

  @override
  List<Object?> get props => [statusFilter, priorityFilter, tagFilter, sortBy];
}
