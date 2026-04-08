import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:vibetasking/core/ai_providers/ai_provider.dart';
import 'package:vibetasking/core/ai_providers/provider_manager.dart';

class SettingsPage extends StatefulWidget {
  final ProviderManager providerManager;
  final VoidCallback onChanged;

  const SettingsPage({
    super.key,
    required this.providerManager,
    required this.onChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  ProviderManager get pm => widget.providerManager;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final configs = pm.configs;
    final activeId = pm.activeConfig?.id;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题 + 添加按钮
          Row(
            children: [
              Text('AI Provider 设置',
                  style: theme.textTheme.headlineSmall),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _showProviderDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('添加 Provider'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Provider 列表
          Expanded(
            child: configs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.settings_outlined,
                            size: 64,
                            color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                        const SizedBox(height: 16),
                        const Text('还没有配置 AI Provider'),
                        const SizedBox(height: 8),
                        const Text('点击上方"添加 Provider"开始配置'),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: configs.length,
                    itemBuilder: (context, index) {
                      final config = configs[index];
                      final isActive = config.id == activeId;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isActive
                                ? theme.colorScheme.primary
                                : theme.colorScheme.surfaceContainerHighest,
                            child: Icon(
                              _providerIcon(config.type),
                              color: isActive
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.onSurface,
                              size: 20,
                            ),
                          ),
                          title: Text(config.name),
                          subtitle: Text(
                            '${config.type} · ${config.model}',
                            style: theme.textTheme.bodySmall,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isActive)
                                Chip(
                                  label: const Text('当前使用'),
                                  backgroundColor:
                                      theme.colorScheme.primaryContainer,
                                  labelStyle: TextStyle(
                                      color:
                                          theme.colorScheme.onPrimaryContainer,
                                      fontSize: 12),
                                )
                              else
                                TextButton(
                                  onPressed: () async {
                                    await pm.setActive(config.id);
                                    widget.onChanged();
                                    setState(() {});
                                  },
                                  child: const Text('设为当前'),
                                ),
                              // #9 连通性测试
                              IconButton(
                                icon: const Icon(Icons.wifi_tethering, size: 18),
                                onPressed: () => _testConnection(config),
                                tooltip: '测试连接',
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                onPressed: () =>
                                    _showProviderDialog(existing: config),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    size: 18, color: Colors.red),
                                onPressed: () async {
                                  // #6 删除确认
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('确认删除'),
                                      content: Text('确定要删除「${config.name}」吗？'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, false),
                                          child: const Text('取消'),
                                        ),
                                        FilledButton(
                                          onPressed: () => Navigator.pop(ctx, true),
                                          style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                          child: const Text('删除'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm != true) return;
                                  await pm.removeProvider(config.id);
                                  widget.onChanged();
                                  setState(() {});
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _testConnection(AIProviderConfig config) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('正在测试连接...')),
    );

    final provider = pm.createProvider(config);
    if (provider == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('无法创建 Provider 实例')),
      );
      return;
    }

    final ok = await provider.testConnection();
    messenger.clearSnackBars();
    messenger.showSnackBar(SnackBar(
      content: Text(ok ? '✅ 连接成功！' : '❌ 连接失败，请检查配置'),
      backgroundColor: ok ? Colors.green : Colors.red,
    ));
  }

  IconData _providerIcon(String type) {
    switch (type) {
      case 'openai':
        return Icons.auto_awesome;
      case 'claude':
        return Icons.psychology;
      case 'gemini':
        return Icons.diamond;
      case 'ollama':
        return Icons.computer;
      default:
        return Icons.api;
    }
  }

  Future<void> _showProviderDialog({AIProviderConfig? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final apiKeyCtrl = TextEditingController(text: existing?.apiKey ?? '');
    final baseUrlCtrl = TextEditingController(text: existing?.baseUrl ?? '');
    final modelCtrl = TextEditingController(text: existing?.model ?? '');
    var selectedType = existing?.type ?? 'openai';

    // 默认 baseUrl
    final defaultUrls = {
      'openai': 'https://api.openai.com/v1',
      'claude': 'https://api.anthropic.com/v1',
      'gemini': 'https://generativelanguage.googleapis.com/v1beta/openai',
      'ollama': 'http://localhost:11434/v1',
      'custom': '',
    };

    if (existing == null && baseUrlCtrl.text.isEmpty) {
      baseUrlCtrl.text = defaultUrls[selectedType] ?? '';
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? '添加 AI Provider' : '编辑 Provider'),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 类型选择
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: '类型'),
                  items: const [
                    DropdownMenuItem(value: 'openai', child: Text('OpenAI')),
                    DropdownMenuItem(value: 'claude', child: Text('Claude')),
                    DropdownMenuItem(value: 'gemini', child: Text('Gemini')),
                    DropdownMenuItem(value: 'ollama', child: Text('Ollama')),
                    DropdownMenuItem(value: 'custom', child: Text('自定义')),
                  ],
                  onChanged: (v) {
                    setDialogState(() {
                      selectedType = v!;
                      if (baseUrlCtrl.text.isEmpty ||
                          defaultUrls.values.contains(baseUrlCtrl.text)) {
                        baseUrlCtrl.text = defaultUrls[v] ?? '';
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: '显示名称',
                    hintText: '例如：我的 GPT-4o',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: apiKeyCtrl,
                  decoration: const InputDecoration(
                    labelText: 'API Key',
                    hintText: 'sk-...',
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: baseUrlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Base URL',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: modelCtrl,
                  decoration: const InputDecoration(
                    labelText: '模型',
                    hintText: '例如：gpt-4o / claude-sonnet-4-20250514',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;

    final config = AIProviderConfig(
      id: existing?.id ?? const Uuid().v4(),
      name: nameCtrl.text.isEmpty ? selectedType : nameCtrl.text,
      type: selectedType,
      apiKey: apiKeyCtrl.text,
      baseUrl: baseUrlCtrl.text,
      model: modelCtrl.text,
      isActive: existing?.isActive ?? false,
    );

    if (existing != null) {
      await pm.updateProvider(config);
    } else {
      await pm.addProvider(config);
    }
    widget.onChanged();
    setState(() {});
  }
}
