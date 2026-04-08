import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'ai_provider.dart';
import 'openai_compatible_provider.dart';
import 'claude_provider.dart';

/// AI Provider 管理器 — 配置持久化 & Provider 实例化
class ProviderManager {
  List<AIProviderConfig> _configs = [];
  String? _activeId;

  List<AIProviderConfig> get configs => List.unmodifiable(_configs);

  AIProviderConfig? get activeConfig {
    if (_activeId == null) return null;
    try {
      return _configs.firstWhere((c) => c.id == _activeId);
    } catch (_) {
      return _configs.isEmpty ? null : _configs.first;
    }
  }

  /// 根据配置创建 Provider 实例
  AIProvider? createProvider(AIProviderConfig config) {
    switch (config.type) {
      case 'openai':
      case 'custom':
      case 'gemini':
      case 'ollama':
        return OpenAICompatibleProvider(config);
      case 'claude':
        return ClaudeProvider(config);
      default:
        return OpenAICompatibleProvider(config);
    }
  }

  /// 获取当前活跃 Provider
  AIProvider? get activeProvider {
    final config = activeConfig;
    if (config == null) return null;
    return createProvider(config);
  }

  /// 加载配置
  Future<void> load() async {
    final file = await _configFile();
    if (!await file.exists()) {
      _configs = [];
      _activeId = null;
      return;
    }
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    _configs = (json['providers'] as List)
        .map((e) => AIProviderConfig.fromJson(e as Map<String, dynamic>))
        .toList();
    _activeId = json['activeId'] as String?;
  }

  /// 保存配置
  Future<void> save() async {
    final file = await _configFile();
    await file.writeAsString(jsonEncode({
      'activeId': _activeId,
      'providers': _configs.map((c) => c.toJson()).toList(),
    }));
  }

  /// 添加 Provider
  Future<void> addProvider(AIProviderConfig config) async {
    _configs = [..._configs, config];
    if (_configs.length == 1) _activeId = config.id;
    await save();
  }

  /// 更新 Provider
  Future<void> updateProvider(AIProviderConfig config) async {
    _configs = _configs.map((c) => c.id == config.id ? config : c).toList();
    await save();
  }

  /// 删除 Provider
  Future<void> removeProvider(String id) async {
    _configs = _configs.where((c) => c.id != id).toList();
    if (_activeId == id) {
      _activeId = _configs.isEmpty ? null : _configs.first.id;
    }
    await save();
  }

  /// 设置活跃 Provider
  Future<void> setActive(String id) async {
    _activeId = id;
    await save();
  }

  Future<File> _configFile() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'ai_providers.json'));
  }
}
