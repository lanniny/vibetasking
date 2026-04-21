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

  /// 智能规范化 Base URL，自动补全 /v1 路径
  static String _normalizeBaseUrl(String rawUrl) {
    var url = rawUrl.trim();
    // 去除末尾斜杠
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    // 如果已包含完整 chat/completions 路径，提取 base
    if (url.endsWith('/chat/completions')) {
      url = url.substring(0, url.length - '/chat/completions'.length);
    }
    // 如果 URL 不含版本路径 (/v1, /v2 等)，自动追加 /v1
    final uri = Uri.tryParse(url);
    if (uri != null) {
      final path = uri.path;
      // 检查路径中是否已有 /v1, /v2 等版本号或 /api 前缀
      if (!RegExp(r'/v\d').hasMatch(path) && !path.contains('/api')) {
        url = '$url/v1';
      }
    }
    return url;
  }

  @override
  Future<String> chat(List<ChatMessage> messages) async {
    final baseUrl = _normalizeBaseUrl(config.baseUrl);
    final endpoint = '$baseUrl/chat/completions';

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
        '您输入的 Base URL: ${config.baseUrl}\n'
        '提示: 请确保 Base URL 指向 API 端点，例如:\n'
        '  • https://api.openai.com/v1\n'
        '  • https://your-domain.com/v1\n'
        '程序已自动尝试补全 /v1，但仍返回 HTML，请检查域名是否正确。',
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
