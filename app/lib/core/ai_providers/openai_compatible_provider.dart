import 'dart:convert';
import 'package:http/http.dart' as http;
import 'ai_provider.dart';

/// OpenAI 兼容 Provider — 支持 OpenAI / DeepSeek / 自定义端点
class OpenAICompatibleProvider implements AIProvider {
  final AIProviderConfig config;

  OpenAICompatibleProvider(this.config);

  @override
  String get id => config.id;

  @override
  String get displayName => config.name;

  @override
  String get type => config.type;

  @override
  Future<String> chat(List<ChatMessage> messages) async {
    // 确保 baseUrl 不以 / 结尾
    final baseUrl = config.baseUrl.endsWith('/')
        ? config.baseUrl.substring(0, config.baseUrl.length - 1)
        : config.baseUrl;

    // 如果 baseUrl 已经包含 /chat/completions，不再追加
    final endpoint = baseUrl.endsWith('/chat/completions')
        ? baseUrl
        : '$baseUrl/chat/completions';

    final url = Uri.parse(endpoint);
    final http.Response response;

    try {
      response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${config.apiKey}',
        },
        body: jsonEncode({
          'model': config.model,
          'messages': messages.map((m) => m.toJson()).toList(),
          'temperature': 0.7,
        }),
      );
    } catch (e) {
      throw Exception('网络请求失败，请检查 Base URL 是否正确: $endpoint\n错误: $e');
    }

    // 检查响应是否为 HTML（常见的配置错误）
    final contentType = response.headers['content-type'] ?? '';
    final body = response.body;

    if (body.trimLeft().startsWith('<!') || body.trimLeft().startsWith('<html')) {
      throw Exception(
        '服务器返回了 HTML 而不是 JSON，Base URL 可能配置错误。\n'
        '当前请求地址: $endpoint\n'
        'HTTP 状态码: ${response.statusCode}\n'
        '提示: 请确保 Base URL 指向 API 端点（如 https://api.openai.com/v1）',
      );
    }

    if (response.statusCode != 200) {
      throw Exception(
        'AI 请求失败 (${response.statusCode}): ${_truncate(body, 300)}',
      );
    }

    try {
      final data = jsonDecode(body) as Map<String, dynamic>;

      // 处理 API 返回的错误
      if (data.containsKey('error')) {
        final error = data['error'];
        final msg = error is Map ? error['message'] ?? error : error;
        throw Exception('AI API 错误: $msg');
      }

      final choices = data['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        throw Exception('AI 返回了空响应');
      }

      return (choices[0]['message']['content'] as String).trim();
    } on FormatException {
      throw Exception(
        '无法解析 AI 响应（非 JSON 格式）。\n'
        '当前请求地址: $endpoint\n'
        'Content-Type: $contentType\n'
        '响应前100字符: ${_truncate(body, 100)}',
      );
    }
  }

  @override
  Future<bool> testConnection() async {
    try {
      final result = await chat([
        const ChatMessage(role: 'user', content: 'Hi, reply with "ok"'),
      ]);
      return result.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static String _truncate(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max)}...';
}
