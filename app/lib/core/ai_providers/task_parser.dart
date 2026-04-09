import 'dart:convert';
import 'ai_provider.dart';

/// AI 返回的结构化任务
class ParsedTask {
  final String title;
  final String? description;
  final String priority; // urgent/high/medium/low
  final DateTime? dueDate;
  final DateTime? startTime; // 精确开始时间
  final DateTime? endTime;   // 精确结束时间
  final List<String> tags;
  final List<ParsedTask> subTasks;

  const ParsedTask({
    required this.title,
    this.description,
    this.priority = 'medium',
    this.dueDate,
    this.startTime,
    this.endTime,
    this.tags = const [],
    this.subTasks = const [],
  });

  factory ParsedTask.fromJson(Map<String, dynamic> json) {
    return ParsedTask(
      title: json['title'] as String? ?? '未命名任务',
      description: json['description'] as String?,
      priority: json['priority'] as String? ?? 'medium',
      dueDate: json['due_date'] != null
          ? DateTime.tryParse(json['due_date'] as String)
          : null,
      startTime: json['start_time'] != null
          ? DateTime.tryParse(json['start_time'] as String)
          : null,
      endTime: json['end_time'] != null
          ? DateTime.tryParse(json['end_time'] as String)
          : null,
      tags: (json['tags'] as List?)?.cast<String>() ?? [],
      subTasks: (json['sub_tasks'] as List?)
              ?.map((e) => ParsedTask.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// AI 操作指令（删除/修改/完成等）
class ParsedAction {
  final String type; // delete / update_status / update_priority
  final int taskId;
  final String? value; // 新状态/新优先级

  const ParsedAction({
    required this.type,
    required this.taskId,
    this.value,
  });

  factory ParsedAction.fromJson(Map<String, dynamic> json) {
    return ParsedAction(
      type: json['type'] as String,
      taskId: json['task_id'] as int,
      value: json['value'] as String?,
    );
  }
}

/// AI 回复解析结果
class AIResponse {
  final String message;
  final List<ParsedTask> tasks;
  final List<ParsedAction> actions;

  const AIResponse({
    required this.message,
    this.tasks = const [],
    this.actions = const [],
  });
}

/// 任务解析服务
class TaskParser {
  static const systemPrompt = '''
你是 VibeTasKing 的任务管理 AI 助手。你可以查看、创建、修改、删除用户的任务。

## 你的能力
1. **查看任务**：根据下方任务列表回答问题
2. **创建任务**：通过 tasks 数组创建新任务
3. **删除任务**：通过 actions 数组删除任务（需要 task_id）
4. **修改任务**：通过 actions 数组修改任务状态或优先级
5. **智能建议**：根据任务列表给出时间管理建议

## 当前任务列表
{task_context}

## 精确时间安排
{time_scheduling_hint}

## JSON 响应格式
当需要操作任务时，你的回复必须包含一个 JSON 代码块：

```json
{
  "message": "操作说明（自然语言）",
  "tasks": [
    {
      "title": "新任务标题",
      "description": "描述（可选）",
      "priority": "urgent|high|medium|low",
      "due_date": "2026-04-10",
      "start_time": "2026-04-10T09:00:00（精确开始时间，仅时间安排模式）",
      "end_time": "2026-04-10T10:30:00（精确结束时间，仅时间安排模式）",
      "tags": ["标签"],
      "sub_tasks": [{"title": "子任务", "priority": "medium", "start_time": "...", "end_time": "...", "tags": []}]
    }
  ],
  "actions": [
    {"type": "delete", "task_id": 1},
    {"type": "update_status", "task_id": 2, "value": "done"},
    {"type": "update_priority", "task_id": 3, "value": "urgent"}
  ]
}
```

## 操作类型说明
- `delete`：删除指定 task_id 的任务
- `update_status`：修改任务状态，value 可选 todo / in_progress / done
- `update_priority`：修改优先级，value 可选 urgent / high / medium / low

## 规则
- task_id 从上方任务列表中获取，每个任务的 id 已标注
- 用户说"删掉所有待办"→ 对所有 status=todo 的任务生成 delete action
- 用户说"把XX标记为完成"→ 生成 update_status action
- 用户说"创建任务"→ 在 tasks 数组中添加
- 不需要操作时 tasks 和 actions 都为空数组
- priority 只能是 urgent/high/medium/low
- due_date 用 ISO 8601 格式，今天是 {today}
- 如果用户提到"明天"，计算实际日期
- message 字段始终包含友好的中文回复
''';

  /// 解析 AI 回复
  static AIResponse parse(String aiReply) {
    final jsonMatch =
        RegExp(r'```json\s*([\s\S]*?)\s*```').firstMatch(aiReply);

    if (jsonMatch != null) {
      try {
        final json =
            jsonDecode(jsonMatch.group(1)!) as Map<String, dynamic>;
        return _parseJson(json, aiReply);
      } catch (_) {}
    }

    // 尝试直接解析
    try {
      final json = jsonDecode(aiReply) as Map<String, dynamic>;
      if (json.containsKey('tasks') || json.containsKey('actions')) {
        return _parseJson(json, aiReply);
      }
    } catch (_) {}

    return AIResponse(message: aiReply);
  }

  static AIResponse _parseJson(Map<String, dynamic> json, String fallback) {
    return AIResponse(
      message: json['message'] as String? ?? fallback,
      tasks: (json['tasks'] as List?)
              ?.map((e) => ParsedTask.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      actions: (json['actions'] as List?)
              ?.map((e) => ParsedAction.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  static const _timeOn = '''已开启。创建任务时，你必须为每个任务安排具体的时间段（start_time 和 end_time），
根据任务的优先级和预估工作量合理安排。例如上午安排重要任务，下午安排常规任务。
时间格式为 ISO 8601（如 2026-04-10T09:00:00）。如果用户没指定具体时间，你要智能推荐。''';

  static const _timeOff = '''未开启。不需要设置 start_time 和 end_time 字段。''';

  /// 构建系统提示词
  static String buildSystemPrompt(
    String today, {
    String taskContext = '（暂无任务）',
    bool enableTimeScheduling = false,
  }) {
    return systemPrompt
        .replaceAll('{today}', today)
        .replaceAll('{task_context}', taskContext)
        .replaceAll('{time_scheduling_hint}',
            enableTimeScheduling ? _timeOn : _timeOff);
  }
}
