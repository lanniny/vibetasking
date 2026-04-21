import 'dart:convert';
import 'package:http/http.dart' as http;
import 'ai_provider.dart';

/// Claude (Anthropic) Provider
class ClaudeProvider implements AIProvider {
  final AIProviderConfig config;

  ClaudeProvider(this.config);

  @override
  String get id => config.id;

  @override
  String get displayName => config.name;

  @override
  String get type => 'claude';

  /// 智能规范化 Base URL：自动补全 /v1，去尾部斜杠
  static String _normalizeBaseUrl(String rawUrl) {
    var url = rawUrl.trim();
    if (url.isEmpty) return 'https://api.anthropic.com/v1';
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (url.endsWith('/messages')) {
      url = url.substring(0, url.length - '/messages'.length);
    }
    final uri = Uri.tryParse(url);
    if (uri != null) {
      final path = uri.path;
      if (!RegExp(r'/v\d').hasMatch(path) && !path.contains('/api')) {
        url = '$url/v1';
      }
    }
    return url;
  }

  @override
  Future<String> chat(List<ChatMessage> messages) async {
    final baseUrl = _normalizeBaseUrl(config.baseUrl);
    final endpoint = '$baseUrl/messages';
    final url = Uri.parse(endpoint);

    // 提取 system message
    String? systemPrompt;
    final apiMessages = <Map<String, dynamic>>[];
    for (final msg in messages) {
      if (msg.role == 'system') {
        systemPrompt = msg.content;
      } else {
        apiMessages.add({'role': msg.role, 'content': msg.content});
      }
    }

    final reqBody = <String, dynamic>{
      'model': config.model,
      'max_tokens': 4096,
      'messages': apiMessages,
    };
    if (systemPrompt != null) {
      reqBody['system'] = systemPrompt;
    }

    final http.Response response;
    try {
      response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': config.apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode(reqBody),
      );
    } catch (e) {
      throw Exception('网络请求失败，请检查 Base URL: $endpoint\n错误: $e');
    }

    final body = response.body;

    // 检查 HTML 响应
    if (body.trimLeft().startsWith('<!') || body.trimLeft().startsWith('<html')) {
      throw Exception(
        '服务器返回了 HTML 而不是 JSON，Base URL 可能配置错误。\n'
        '当前请求地址: $endpoint\n'
        'HTTP 状态码: ${response.statusCode}\n'
        '提示: Claude API 的 Base URL 通常是 https://api.anthropic.com/v1',
      );
    }

    try {
      final data = jsonDecode(body) as Map<String, dynamic>;

      // 处理 API 错误
      if (data.containsKey('error')) {
        final error = data['error'];
        final msg = error is Map ? error['message'] ?? error : error;
        throw Exception('Claude API 错误: $msg');
      }

      if (response.statusCode != 200) {
        throw Exception(
          'Claude 请求失败 (${response.statusCode}): ${_truncate(body, 300)}',
        );
      }

      final content = data['content'] as List?;
      if (content == null || content.isEmpty) {
        throw Exception('Claude 返回了空响应');
      }

      return (content[0]['text'] as String).trim();
    } on FormatException {
      throw Exception(
        '无法解析响应（非 JSON）。\n'
        '请求地址: $endpoint\n'
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
