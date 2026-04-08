import 'dart:async';
import 'package:drift/drift.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vibetasking/data/database/database.dart';
import 'task_event.dart';
import 'task_state.dart';

class TaskBloc extends Bloc<TaskEvent, TaskState> {
  final AppDatabase _db;
  StreamSubscription<List<Task>>? _tasksSub;

  TaskBloc(this._db) : super(const TaskState()) {
    on<LoadTasks>(_onLoadTasks);
    on<AddTask>(_onAddTask);
    on<UpdateTaskStatus>(_onUpdateTaskStatus);
    on<DeleteTask>(_onDeleteTask);
    on<FilterTasks>(_onFilterTasks);
  }

  Future<void> _onLoadTasks(LoadTasks event, Emitter<TaskState> emit) async {
    emit(state.copyWith(status: TaskStatus.loading));
    await _tasksSub?.cancel();
    _tasksSub = _db.watchAllTasks().listen(
      (tasks) => add(FilterTasks(
        statusFilter: state.statusFilter,
        priorityFilter: state.priorityFilter,
        sortBy: state.sortBy,
      )),
    );
    try {
      final tasks = await _db.getAllTasks();
      emit(state.copyWith(status: TaskStatus.loaded, tasks: tasks));
    } catch (e) {
      emit(state.copyWith(
        status: TaskStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onAddTask(AddTask event, Emitter<TaskState> emit) async {
    try {
      final taskId = await _db.insertTask(TasksCompanion.insert(
        title: event.title,
        description: Value(event.description),
        priority: Value(event.priority),
        dueDate: Value(event.dueDate),
        parentId: Value(event.parentId),
      ));

      // 处理标签
      if (event.tags.isNotEmpty) {
        final tagIds = <int>[];
        for (final tagName in event.tags) {
          final existing = (await _db.getAllTags())
              .where((t) => t.name == tagName)
              .toList();
          if (existing.isNotEmpty) {
            tagIds.add(existing.first.id);
          } else {
            final id = await _db
                .insertTag(TagsCompanion.insert(name: tagName));
            tagIds.add(id);
          }
        }
        await _db.setTagsForTask(taskId, tagIds);
      }

      // 重新加载
      final tasks = await _db.getAllTasks();
      emit(state.copyWith(status: TaskStatus.loaded, tasks: tasks));
    } catch (e) {
      emit(state.copyWith(
        status: TaskStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onUpdateTaskStatus(
    UpdateTaskStatus event,
    Emitter<TaskState> emit,
  ) async {
    try {
      final task = await _db.getTaskById(event.taskId);
      await _db.updateTask(TasksCompanion(
        id: Value(task.id),
        title: Value(task.title),
        description: Value(task.description),
        status: Value(event.newStatus),
        priority: Value(task.priority),
        dueDate: Value(task.dueDate),
        parentId: Value(task.parentId),
        createdAt: Value(task.createdAt),
        updatedAt: Value(DateTime.now()),
      ));
      final tasks = await _db.getAllTasks();
      emit(state.copyWith(status: TaskStatus.loaded, tasks: tasks));
    } catch (e) {
      emit(state.copyWith(
        status: TaskStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onDeleteTask(
    DeleteTask event,
    Emitter<TaskState> emit,
  ) async {
    await _db.deleteTask(event.taskId);
    final tasks = await _db.getAllTasks();
    emit(state.copyWith(status: TaskStatus.loaded, tasks: tasks));
  }

  void _onFilterTasks(FilterTasks event, Emitter<TaskState> emit) {
    var filtered = List<Task>.from(state.tasks);

    // 排序
    switch (event.sortBy) {
      case 'priority':
        const order = {'urgent': 0, 'high': 1, 'medium': 2, 'low': 3};
        filtered.sort((a, b) =>
            (order[a.priority] ?? 2).compareTo(order[b.priority] ?? 2));
        break;
      case 'due_date':
        filtered.sort((a, b) {
          if (a.dueDate == null && b.dueDate == null) return 0;
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          return a.dueDate!.compareTo(b.dueDate!);
        });
        break;
      default:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    emit(state.copyWith(
      tasks: filtered,
      statusFilter: event.statusFilter,
      priorityFilter: event.priorityFilter,
      sortBy: event.sortBy,
    ));
  }

  @override
  Future<void> close() {
    _tasksSub?.cancel();
    return super.close();
  }
}
