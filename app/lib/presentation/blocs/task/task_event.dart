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
  final DateTime? startTime;
  final DateTime? endTime;
  final List<String> tags;
  final int? parentId;

  const AddTask({
    required this.title,
    this.description,
    this.priority = 'medium',
    this.dueDate,
    this.startTime,
    this.endTime,
    this.tags = const [],
    this.parentId,
  });

  @override
  List<Object?> get props =>
      [title, description, priority, dueDate, startTime, endTime, tags, parentId];
}

/// 原子化创建父任务 + 子任务（解决 parentId 问题）
class AddTaskWithSubTasks extends TaskEvent {
  final AddTask parent;
  final List<AddTask> subTasks;

  const AddTaskWithSubTasks({required this.parent, required this.subTasks});

  @override
  List<Object?> get props => [parent, subTasks];
}

class EditTask extends TaskEvent {
  final int taskId;
  final String? title;
  final String? description;
  final String? status;
  final String? priority;
  final DateTime? dueDate;
  final bool clearDueDate;
  final List<String>? tags;
  // Claude YOLO 字段
  final String? workingDir;
  final bool clearWorkingDir;
  final String? aiPrompt;
  final bool clearAiPrompt;

  const EditTask({
    required this.taskId,
    this.title,
    this.description,
    this.status,
    this.priority,
    this.dueDate,
    this.clearDueDate = false,
    this.tags,
    this.workingDir,
    this.clearWorkingDir = false,
    this.aiPrompt,
    this.clearAiPrompt = false,
  });

  @override
  List<Object?> get props => [
        taskId,
        title,
        description,
        status,
        priority,
        dueDate,
        clearDueDate,
        tags,
        workingDir,
        clearWorkingDir,
        aiPrompt,
        clearAiPrompt,
      ];
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

class SearchTasks extends TaskEvent {
  final String query;

  const SearchTasks(this.query);

  @override
  List<Object?> get props => [query];
}

class FilterTasks extends TaskEvent {
  final String? statusFilter;
  final String? priorityFilter;
  final String? tagFilter;
  final String sortBy;

  const FilterTasks({
    this.statusFilter,
    this.priorityFilter,
    this.tagFilter,
    this.sortBy = 'created_at',
  });

  @override
  List<Object?> get props => [statusFilter, priorityFilter, tagFilter, sortBy];
}
