/// AI Provider 统一抽象接口
abstract class AIProvider {
  String get id;
  String get displayName;
  String get type; // openai / claude / gemini / ollama / custom

  /// 发送消息并获取回复
  Future<String> chat(List<ChatMessage> messages);

  /// 测试连通性
  Future<bool> testConnection();
}

class ChatMessage {
  final String role; // system / user / assistant
  final String content;

  const ChatMessage({required this.role, required this.content});

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

/// AI Provider 配置
class AIProviderConfig {
  final String id;
  final String name;
  final String type;
  final String apiKey;
  final String baseUrl;
  final String model;
  final bool isActive;

  const AIProviderConfig({
    required this.id,
    required this.name,
    required this.type,
    required this.apiKey,
    required this.baseUrl,
    required this.model,
    this.isActive = false,
  });

  AIProviderConfig copyWith({
    String? id,
    String? name,
    String? type,
    String? apiKey,
    String? baseUrl,
    String? model,
    bool? isActive,
  }) {
    return AIProviderConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'apiKey': apiKey,
        'baseUrl': baseUrl,
        'model': model,
        'isActive': isActive,
      };

  factory AIProviderConfig.fromJson(Map<String, dynamic> json) {
    return AIProviderConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      apiKey: json['apiKey'] as String,
      baseUrl: json['baseUrl'] as String,
      model: json['model'] as String,
      isActive: json['isActive'] as bool? ?? false,
    );
  }
}
