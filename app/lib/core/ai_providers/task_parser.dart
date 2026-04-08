import 'dart:convert';
import 'ai_provider.dart';

/// AI 返回的结构化任务
class ParsedTask {
  final String title;
  final String? description;
  final String priority; // urgent/high/medium/low
  final DateTime? dueDate;
  final List<String> tags;
  final List<ParsedTask> subTasks;

  const ParsedTask({
    required this.title,
    this.description,
    this.priority = 'medium',
    this.dueDate,
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
      tags: (json['tags'] as List?)?.cast<String>() ?? [],
      subTasks: (json['sub_tasks'] as List?)
              ?.map((e) => ParsedTask.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// AI 回复解析结果
class AIResponse {
  final String message; // 给用户看的自然语言回复
  final List<ParsedTask> tasks; // 解析出的任务

  const AIResponse({required this.message, this.tasks = const []});
}

/// 任务解析服务 — 将 AI 返回内容解析为结构化任务
class TaskParser {
  static const systemPrompt = '''
你是 VibeTasKing 的任务管理 AI 助手。你可以查看用户当前的所有任务，也可以帮用户创建新任务。

## 你的能力
1. **查看任务**：用户当前的任务列表在下方提供，你可以回答关于任务状态、优先级、截止日期的问题
2. **创建任务**：当用户想创建任务或规划项目时，返回结构化 JSON
3. **修改建议**：根据任务列表给出时间管理和优先级建议

## 当前任务列表
{task_context}

## 创建任务格式
当需要创建任务时，你的回复必须包含一个 JSON 代码块：

```json
{
  "message": "好的，我帮你创建了以下任务：",
  "tasks": [
    {
      "title": "任务标题",
      "description": "任务描述（可选）",
      "priority": "urgent|high|medium|low",
      "due_date": "2026-04-10（ISO格式，可选）",
      "tags": ["标签1", "标签2"],
      "sub_tasks": [
        {
          "title": "子任务标题",
          "priority": "medium",
          "tags": []
        }
      ]
    }
  ]
}
```

## 规则
- priority 只能是 urgent/high/medium/low
- due_date 使用 ISO 8601 格式，今天是 {today}
- 如果用户提到"明天"，计算实际日期
- 如果用户说"帮我规划XXX项目"，将其拆解为 3-8 个子任务
- 如果不需要创建任务，tasks 数组为空
- 如果用户询问现有任务，根据上方任务列表回答
- message 字段始终包含友好的自然语言回复
''';

  /// 解析 AI 回复为结构化结果
  static AIResponse parse(String aiReply) {
    // 尝试从回复中提取 JSON 块
    final jsonMatch = RegExp(r'```json\s*([\s\S]*?)\s*```').firstMatch(aiReply);

    if (jsonMatch != null) {
      try {
        final json =
            jsonDecode(jsonMatch.group(1)!) as Map<String, dynamic>;
        return AIResponse(
          message: json['message'] as String? ?? aiReply,
          tasks: (json['tasks'] as List?)
                  ?.map(
                      (e) => ParsedTask.fromJson(e as Map<String, dynamic>))
                  .toList() ??
              [],
        );
      } catch (_) {
        // JSON 解析失败，当作普通回复
      }
    }

    // 尝试直接解析整个回复为 JSON
    try {
      final json = jsonDecode(aiReply) as Map<String, dynamic>;
      if (json.containsKey('tasks')) {
        return AIResponse(
          message: json['message'] as String? ?? '任务已创建',
          tasks: (json['tasks'] as List)
              .map((e) => ParsedTask.fromJson(e as Map<String, dynamic>))
              .toList(),
        );
      }
    } catch (_) {
      // 不是 JSON，正常回复
    }

    return AIResponse(message: aiReply);
  }

  /// 构建带上下文的系统提示词
  static String buildSystemPrompt(String today, {String taskContext = '（暂无任务）'}) {
    return systemPrompt
        .replaceAll('{today}', today)
        .replaceAll('{task_context}', taskContext);
  }
}
