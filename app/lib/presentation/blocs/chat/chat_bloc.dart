import 'package:drift/drift.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';
import 'package:vibetasking/data/database/database.dart';
import 'package:vibetasking/core/ai_providers/ai_provider.dart' as ai;
import 'package:vibetasking/core/ai_providers/provider_manager.dart';
import 'package:vibetasking/core/ai_providers/task_parser.dart';
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

class ChatState extends Equatable {
  final ChatStatus status;
  final List<ChatMessage> messages;
  final String? errorMessage;

  const ChatState({
    this.status = ChatStatus.idle,
    this.messages = const [],
    this.errorMessage,
  });

  ChatState copyWith({
    ChatStatus? status,
    List<ChatMessage>? messages,
    String? errorMessage,
  }) {
    return ChatState(
      status: status ?? this.status,
      messages: messages ?? this.messages,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, messages, errorMessage];
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
    emit(state.copyWith(status: ChatStatus.sending, messages: messages));

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
      // 构建消息历史
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final aiMessages = <ai.ChatMessage>[
        ai.ChatMessage(
          role: 'system',
          content: TaskParser.buildSystemPrompt(today),
        ),
        // 最近 20 条上下文
        ...messages.reversed.take(20).toList().reversed.map(
              (m) => ai.ChatMessage(role: m.role, content: m.content),
            ),
      ];

      final reply = await provider.chat(aiMessages);

      // 解析回复
      final parsed = TaskParser.parse(reply);

      // 创建解析出的任务
      for (final task in parsed.tasks) {
        _taskBloc.add(AddTask(
          title: task.title,
          description: task.description,
          priority: task.priority,
          dueDate: task.dueDate,
          tags: task.tags,
        ));

        // 子任务在 TaskBloc 中以 parentId 方式处理
        // MVP 阶段先扁平化创建
        for (final sub in task.subTasks) {
          _taskBloc.add(AddTask(
            title: sub.title,
            description: sub.description,
            priority: sub.priority,
            dueDate: sub.dueDate,
            tags: sub.tags,
          ));
        }
      }

      // 保存 AI 回复
      await _db.insertMessage(ChatMessagesCompanion.insert(
        role: 'assistant',
        content: parsed.message,
      ));
      messages = await _db.getAllMessages();
      emit(state.copyWith(status: ChatStatus.idle, messages: messages));
    } catch (e) {
      await _db.insertMessage(ChatMessagesCompanion.insert(
        role: 'assistant',
        content: '❌ 请求失败: $e',
      ));
      messages = await _db.getAllMessages();
      emit(state.copyWith(
        status: ChatStatus.error,
        messages: messages,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onClearChat(ClearChat event, Emitter<ChatState> emit) async {
    await _db.clearMessages();
    emit(const ChatState());
  }
}
