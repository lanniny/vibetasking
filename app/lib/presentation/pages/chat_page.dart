import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:vibetasking/core/theme/app_theme.dart';
import 'package:vibetasking/presentation/blocs/chat/chat_bloc.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    // H6: 防止发送中重复提交
    if (context.read<ChatBloc>().state.status == ChatStatus.sending) return;
    context.read<ChatBloc>().add(SendMessage(text));
    _controller.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // 顶部栏
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.auto_awesome, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text('AI 任务助手', style: theme.textTheme.titleSmall),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('清除聊天记录'),
                      content: const Text('确定要清除所有聊天记录吗？'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('取消'),
                        ),
                        FilledButton(
                          onPressed: () {
                            context.read<ChatBloc>().add(ClearChat());
                            Navigator.pop(ctx);
                          },
                          child: const Text('清除'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.delete_sweep, size: 16),
                label: const Text('清除'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // 消息列表
        Expanded(
          child: BlocConsumer<ChatBloc, ChatState>(
            listener: (context, state) => _scrollToBottom(),
            builder: (context, state) {
              if (state.messages.isEmpty) {
                return _EmptyChat(theme: theme);
              }

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: state.messages.length +
                    (state.lastCreatedTasks.isNotEmpty ? 1 : 0),
                itemBuilder: (context, index) {
                  // 最后一项：内联创建的任务卡片
                  if (index == state.messages.length &&
                      state.lastCreatedTasks.isNotEmpty) {
                    return _InlineTaskCards(tasks: state.lastCreatedTasks);
                  }

                  final msg = state.messages[index];
                  final isUser = msg.role == 'user';
                  return _ChatBubble(
                    content: msg.content,
                    isUser: isUser,
                  );
                },
              );
            },
          ),
        ),

        // 错误提示条（不持久化）
        BlocBuilder<ChatBloc, ChatState>(
          builder: (context, state) {
            if (state.status != ChatStatus.error ||
                state.errorMessage == null) {
              return const SizedBox.shrink();
            }
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.red.withValues(alpha: 0.1),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 16, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.errorMessage!,
                      style: const TextStyle(fontSize: 12, color: Colors.red),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        // 发送中指示器
        BlocBuilder<ChatBloc, ChatState>(
          builder: (context, state) {
            if (state.status != ChatStatus.sending) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('AI 思考中...',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      )),
                ],
              ),
            );
          },
        ),

        // 输入框
        BlocBuilder<ChatBloc, ChatState>(
          buildWhen: (prev, curr) => prev.status != curr.status,
          builder: (context, chatState) {
            final isSending = chatState.status == ChatStatus.sending;
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                border: Border(
                  top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: !isSending,
                      decoration: const InputDecoration(
                        hintText: '描述你的任务，AI 帮你安排...',
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: isSending ? null : _send,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

// 空状态引导
class _EmptyChat extends StatelessWidget {
  final ThemeData theme;
  const _EmptyChat({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome,
              size: 64,
              color: theme.colorScheme.primary.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            '跟 AI 说说你想做什么',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),
          // 示例提示
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _SuggestionChip('帮我创建一个明天截止的任务：完成报告'),
              _SuggestionChip('帮我规划一个网站开发项目'),
              _SuggestionChip('这周还有哪些紧急的事情要做？'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String text;
  const _SuggestionChip(this.text);

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(text, style: const TextStyle(fontSize: 12)),
      onPressed: () {
        context.read<ChatBloc>().add(SendMessage(text));
      },
      visualDensity: VisualDensity.compact,
    );
  }
}

// #11 Markdown 渲染气泡
class _ChatBubble extends StatelessWidget {
  final String content;
  final bool isUser;

  const _ChatBubble({required this.content, required this.isUser});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isUser
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: isUser
            ? SelectableText(
                content,
                style: TextStyle(
                  color: theme.colorScheme.onPrimary,
                  height: 1.5,
                ),
              )
            : MarkdownBody(
                data: content,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                    color: theme.colorScheme.onSurface,
                    height: 1.5,
                  ),
                  code: TextStyle(
                    backgroundColor:
                        theme.colorScheme.surface.withValues(alpha: 0.5),
                    color: theme.colorScheme.primary,
                    fontSize: 13,
                  ),
                ),
                selectable: true,
              ),
      ),
    );
  }
}

// #5 内联任务卡片展示
class _InlineTaskCards extends StatelessWidget {
  final List<InlineCreatedTask> tasks;
  const _InlineTaskCards({required this.tasks});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12, left: 0, right: 60),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle,
                  size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                '已创建 ${tasks.length} 个任务',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...tasks.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppTheme.priorityColor(t.priority),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        t.title,
                        style: theme.textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (t.dueDate != null)
                      Text(
                        ' ${t.dueDate!.month}/${t.dueDate!.day}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
