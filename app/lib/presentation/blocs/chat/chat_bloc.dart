import 'package:drift/drift.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';
import 'package:vibetasking/data/database/database.dart';
import 'package:vibetasking/core/ai_providers/ai_provider.dart' as ai;
import 'package:vibetasking/core/ai_providers/provider_manager.dart';
import 'package:vibetasking/core/ai_providers/task_parser.dart';
import 'package:vibetasking/core/config/app_settings.dart';
import 'package:vibetasking/presentation/blocs/task/task_bloc.dart';
import 'package:vibetasking/presentation/blocs/task/task_event.dart';

// ── Events ──

abstract class ChatEvent extends Equatable {
  const ChatEvent();
  @override
  List<Object?> get props => [];
}

class LoadMessages extends ChatEvent {}

class SendMessage extends ChatEvent {
  final String content;
  const SendMessage(this.content);
  @override
  List<Object?> get props => [content];
}

class ClearChat extends ChatEvent {}

// ── State ──

enum ChatStatus { idle, sending, error }

/// 聊天中内联展示的已创建任务
class InlineCreatedTask {
  final String title;
  final String priority;
  final DateTime? dueDate;
  final List<String> tags;

  const InlineCreatedTask({
    required this.title,
    this.priority = 'medium',
    this.dueDate,
    this.tags = const [],
  });
}

class ChatState extends Equatable {
  final ChatStatus status;
  final List<ChatMessage> messages;
  final String? errorMessage;
  // 最近一次 AI 创建的任务（用于内联展示）
  final List<InlineCreatedTask> lastCreatedTasks;

  const ChatState({
    this.status = ChatStatus.idle,
    this.messages = const [],
    this.errorMessage,
    this.lastCreatedTasks = const [],
  });

  ChatState copyWith({
    ChatStatus? status,
    List<ChatMessage>? messages,
    String? errorMessage,
    List<InlineCreatedTask>? lastCreatedTasks,
  }) {
    return ChatState(
      status: status ?? this.status,
      messages: messages ?? this.messages,
      errorMessage: errorMessage,
      lastCreatedTasks: lastCreatedTasks ?? this.lastCreatedTasks,
    );
  }

  @override
  List<Object?> get props => [status, messages, errorMessage, lastCreatedTasks];
}

// ── BLoC ──

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final AppDatabase _db;
  final ProviderManager _providerManager;
  final TaskBloc _taskBloc;

  ChatBloc(this._db, this._providerManager, this._taskBloc)
      : super(const ChatState()) {
    on<LoadMessages>(_onLoadMessages);
    on<SendMessage>(_onSendMessage);
    on<ClearChat>(_onClearChat);
  }

  Future<void> _onLoadMessages(
      LoadMessages event, Emitter<ChatState> emit) async {
    final messages = await _db.getAllMessages();
    emit(state.copyWith(messages: messages));
  }

  Future<void> _onSendMessage(
      SendMessage event, Emitter<ChatState> emit) async {
    // 保存用户消息
    await _db.insertMessage(ChatMessagesCompanion.insert(
      role: 'user',
      content: event.content,
    ));
    var messages = await _db.getAllMessages();
    emit(state.copyWith(
      status: ChatStatus.sending,
      messages: messages,
      lastCreatedTasks: const [],
    ));

    // 获取 AI Provider
    final provider = _providerManager.activeProvider;
    if (provider == null) {
      await _db.insertMessage(ChatMessagesCompanion.insert(
        role: 'assistant',
        content: '⚠️ 请先在设置中配置 AI Provider',
      ));
      messages = await _db.getAllMessages();
      emit(state.copyWith(status: ChatStatus.idle, messages: messages));
      return;
    }

    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // 构建任务上下文（含 ID），让 AI 能感知并操作现有任务
      final allTasks = await _db.getAllTasks();
      final taskContext = allTasks.isEmpty
          ? '（暂无任务）'
          : allTasks.map((t) {
              final due = t.dueDate != null
                  ? ' | 截止: ${DateFormat('yyyy-MM-dd').format(t.dueDate!)}'
                  : '';
              return '- id=${t.id} [${t.status}] ${t.title} (${t.priority})$due';
            }).join('\n');

      // 读取时间安排设置
      final settings = await AppSettings.load();

      final aiMessages = <ai.ChatMessage>[
        ai.ChatMessage(
          role: 'system',
          content: TaskParser.buildSystemPrompt(
            today,
            taskContext: taskContext,
            enableTimeScheduling: settings.enableTimeScheduling,
          ),
        ),
        ...messages.reversed.take(20).toList().reversed.map(
              (m) => ai.ChatMessage(role: m.role, content: m.content),
            ),
      ];

      final reply = await provider.chat(aiMessages);
      final parsed = TaskParser.parse(reply);

      // 创建任务（真正的父子层级）
      final createdTasks = <InlineCreatedTask>[];
      for (final task in parsed.tasks) {
        final parentEvent = AddTask(
          title: task.title,
          description: task.description,
          priority: task.priority,
          dueDate: task.dueDate,
          startTime: task.startTime,
          endTime: task.endTime,
          tags: task.tags,
        );
        createdTasks.add(InlineCreatedTask(
          title: task.title,
          priority: task.priority,
          dueDate: task.dueDate,
          tags: task.tags,
        ));

        if (task.subTasks.isEmpty) {
          _taskBloc.add(parentEvent);
        } else {
          // H3: 用 AddTaskWithSubTasks 原子化创建，parentId 正确传递
          final subEvents = task.subTasks.map((sub) {
            createdTasks.add(InlineCreatedTask(
              title: '  ↳ ${sub.title}',
              priority: sub.priority,
              dueDate: sub.dueDate,
              tags: sub.tags,
            ));
            return AddTask(
              title: sub.title,
              description: sub.description,
              priority: sub.priority,
              dueDate: sub.dueDate,
              startTime: sub.startTime,
              endTime: sub.endTime,
              tags: sub.tags,
            );
          }).toList();

          _taskBloc.add(AddTaskWithSubTasks(
            parent: parentEvent,
            subTasks: subEvents,
          ));
        }
      }

      // 执行 actions（删除/修改任务）
      for (final action in parsed.actions) {
        switch (action.type) {
          case 'delete':
            _taskBloc.add(DeleteTask(taskId: action.taskId));
            break;
          case 'update_status':
            if (action.value != null) {
              _taskBloc.add(UpdateTaskStatus(
                taskId: action.taskId,
                newStatus: action.value!,
              ));
            }
            break;
          case 'update_priority':
            if (action.value != null) {
              _taskBloc.add(EditTask(
                taskId: action.taskId,
                priority: action.value,
              ));
            }
            break;
        }
      }

      // 保存 AI 回复
      await _db.insertMessage(ChatMessagesCompanion.insert(
        role: 'assistant',
        content: parsed.message,
      ));
      messages = await _db.getAllMessages();
      emit(state.copyWith(
        status: ChatStatus.idle,
        messages: messages,
        lastCreatedTasks: createdTasks,
      ));
    } catch (e) {
      // #12 修复：错误信息不持久化到数据库，只在 state 中展示
      emit(state.copyWith(
        status: ChatStatus.error,
        messages: messages, // 不插入错误消息到 DB
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onClearChat(ClearChat event, Emitter<ChatState> emit) async {
    await _db.clearMessages();
    emit(const ChatState());
  }
}
