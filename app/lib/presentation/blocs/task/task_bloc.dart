import 'package:drift/drift.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vibetasking/data/database/database.dart';
import 'task_event.dart';
import 'task_state.dart';

class TaskBloc extends Bloc<TaskEvent, TaskState> {
  final AppDatabase _db;

  TaskBloc(this._db) : super(const TaskState()) {
    on<LoadTasks>(_onLoadTasks);
    on<AddTask>(_onAddTask);
    on<AddTaskWithSubTasks>(_onAddTaskWithSubTasks);
    on<EditTask>(_onEditTask);
    on<UpdateTaskStatus>(_onUpdateTaskStatus);
    on<DeleteTask>(_onDeleteTask);
    on<SearchTasks>(_onSearchTasks);
    on<FilterTasks>(_onFilterTasks);
  }

  Future<void> _reload(Emitter<TaskState> emit) async {
    final tasks = await _db.getAllTasks();
    // 加载每个任务的标签
    final tagMap = <int, List<String>>{};
    for (final t in tasks) {
      final tags = await _db.getTagsForTask(t.id);
      if (tags.isNotEmpty) {
        tagMap[t.id] = tags.map((tag) => tag.name).toList();
      }
    }
    emit(state.copyWith(
      status: TaskStatus.loaded,
      allTasks: tasks,
      taskTags: tagMap,
    ));
  }

  Future<void> _onLoadTasks(LoadTasks event, Emitter<TaskState> emit) async {
    emit(state.copyWith(status: TaskStatus.loading));
    await _reload(emit);
  }

  Future<void> _onAddTask(AddTask event, Emitter<TaskState> emit) async {
    try {
      final taskId = await _db.insertTask(TasksCompanion.insert(
        title: event.title,
        description: Value(event.description),
        priority: Value(event.priority),
        dueDate: Value(event.dueDate),
        startTime: Value(event.startTime),
        endTime: Value(event.endTime),
        parentId: Value(event.parentId),
      ));

      if (event.tags.isNotEmpty) {
        await _setTagsByName(taskId, event.tags);
      }

      await _reload(emit);
    } catch (e) {
      emit(state.copyWith(
        status: TaskStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onAddTaskWithSubTasks(
    AddTaskWithSubTasks event,
    Emitter<TaskState> emit,
  ) async {
    try {
      final p = event.parent;
      final parentId = await _db.insertTask(TasksCompanion.insert(
        title: p.title,
        description: Value(p.description),
        priority: Value(p.priority),
        dueDate: Value(p.dueDate),
        startTime: Value(p.startTime),
        endTime: Value(p.endTime),
      ));
      if (p.tags.isNotEmpty) await _setTagsByName(parentId, p.tags);

      // 用真实 parentId 创建子任务
      for (final s in event.subTasks) {
        final subId = await _db.insertTask(TasksCompanion.insert(
          title: s.title,
          description: Value(s.description),
          priority: Value(s.priority),
          dueDate: Value(s.dueDate),
          startTime: Value(s.startTime),
          endTime: Value(s.endTime),
          parentId: Value(parentId),
        ));
        if (s.tags.isNotEmpty) await _setTagsByName(subId, s.tags);
      }

      await _reload(emit);
    } catch (e) {
      emit(state.copyWith(status: TaskStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> _onEditTask(EditTask event, Emitter<TaskState> emit) async {
    try {
      final task = await _db.getTaskById(event.taskId);
      await _db.updateTask(TasksCompanion(
        id: Value(task.id),
        title: Value(event.title ?? task.title),
        description: Value(event.description ?? task.description),
        status: Value(event.status ?? task.status),
        priority: Value(event.priority ?? task.priority),
        dueDate: Value(event.clearDueDate ? null : (event.dueDate ?? task.dueDate)),
        parentId: Value(task.parentId),
        workingDir: Value(event.clearWorkingDir
            ? null
            : (event.workingDir ?? task.workingDir)),
        aiPrompt: Value(event.clearAiPrompt
            ? null
            : (event.aiPrompt ?? task.aiPrompt)),
        createdAt: Value(task.createdAt),
        updatedAt: Value(DateTime.now()),
      ));

      if (event.tags != null) {
        await _setTagsByName(event.taskId, event.tags!);
      }

      await _reload(emit);
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
      await _reload(emit);
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
    try {
      // deleteTask 内部已经在事务中级联清理子任务、TaskTags、Bills 关联
      await _db.deleteTask(event.taskId);
      await _reload(emit);
    } catch (e) {
      emit(state.copyWith(status: TaskStatus.error, errorMessage: e.toString()));
    }
  }

  void _onSearchTasks(SearchTasks event, Emitter<TaskState> emit) {
    emit(state.copyWith(searchQuery: event.query));
  }

  void _onFilterTasks(FilterTasks event, Emitter<TaskState> emit) {
    emit(state.copyWith(
      statusFilter: event.statusFilter,
      priorityFilter: event.priorityFilter,
      tagFilter: event.tagFilter,
      sortBy: event.sortBy,
    ));
  }

  Future<void> _setTagsByName(int taskId, List<String> tagNames) async {
    final tagIds = <int>[];
    for (final name in tagNames) {
      final existing =
          (await _db.getAllTags()).where((t) => t.name == name).toList();
      if (existing.isNotEmpty) {
        tagIds.add(existing.first.id);
      } else {
        final id = await _db.insertTag(TagsCompanion.insert(name: name));
        tagIds.add(id);
      }
    }
    await _db.setTagsForTask(taskId, tagIds);
  }

  @override
  Future<void> close() => super.close();
}
