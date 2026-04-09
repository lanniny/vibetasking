import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:vibetasking/core/ai_providers/ai_provider.dart';
import 'package:vibetasking/core/ai_providers/provider_manager.dart';
import 'package:vibetasking/core/config/app_settings.dart';
import 'package:vibetasking/data/database/database.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vibetasking/presentation/blocs/task/task_bloc.dart';
import 'package:vibetasking/presentation/blocs/task/task_state.dart';

class SettingsPage extends StatefulWidget {
  final ProviderManager providerManager;
  final VoidCallback onChanged;
  final ValueChanged<ThemeMode>? onThemeChanged;

  const SettingsPage({
    super.key,
    required this.providerManager,
    required this.onChanged,
    this.onThemeChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  ProviderManager get pm => widget.providerManager;
  AppSettings? _appSettings;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final s = await AppSettings.load();
    setState(() => _appSettings = s);
  }

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
          // 页面标题
          Text('设置', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 20),

          // 功能设置
          if (_appSettings != null) ...[
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('精确时间安排'),
                    subtitle: const Text('AI 为任务安排具体时间段（如 09:00-10:30）'),
                    secondary: const Icon(Icons.schedule),
                    value: _appSettings!.enableTimeScheduling,
                    onChanged: (v) async {
                      _appSettings = _appSettings!.copyWith(enableTimeScheduling: v);
                      await _appSettings!.save();
                      setState(() {});
                    },
                  ),
                  const Divider(height: 1),
                  // M1: 深色模式切换
                  ListTile(
                    leading: const Icon(Icons.dark_mode),
                    title: const Text('主题模式'),
                    trailing: SegmentedButton<String>(
                      selected: {_appSettings!.themeMode},
                      onSelectionChanged: (v) async {
                        final mode = v.first;
                        _appSettings = _appSettings!.copyWith(themeMode: mode);
                        await _appSettings!.save();
                        setState(() {});
                        final themeMode = switch (mode) {
                          'light' => ThemeMode.light,
                          'dark' => ThemeMode.dark,
                          _ => ThemeMode.system,
                        };
                        widget.onThemeChanged?.call(themeMode);
                      },
                      segments: const [
                        ButtonSegment(value: 'system', label: Text('跟随系统')),
                        ButtonSegment(value: 'light', label: Text('浅色')),
                        ButtonSegment(value: 'dark', label: Text('深色')),
                      ],
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  // M8: 快捷键帮助
                  ListTile(
                    leading: const Icon(Icons.keyboard),
                    title: const Text('快捷键'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showShortcutsDialog(),
                  ),
                  const Divider(height: 1),
                  // H7: 数据导出
                  ListTile(
                    leading: const Icon(Icons.download),
                    title: const Text('导出任务数据'),
                    subtitle: const Text('导出为 JSON 文件'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _exportData(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Provider 标题
          Row(
            children: [
              Text('AI Provider', style: theme.textTheme.titleMedium),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _showProviderDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('添加'),
              ),
            ],
          ),
          const SizedBox(height: 12),

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

  void _showShortcutsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('快捷键'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ShortcutRow('Ctrl + N', '快速创建任务'),
            _ShortcutRow('Ctrl + 1', '切换到聊天'),
            _ShortcutRow('Ctrl + 2', '切换到看板'),
            _ShortcutRow('Ctrl + 3', '切换到列表'),
            _ShortcutRow('Ctrl + 4', '切换到设置'),
            _ShortcutRow('Enter', '发送聊天消息'),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportData() async {
    final taskState = context.read<TaskBloc>().state;
    final tasks = taskState.allTasks.map((t) => {
          'id': t.id,
          'title': t.title,
          'description': t.description,
          'status': t.status,
          'priority': t.priority,
          'dueDate': t.dueDate?.toIso8601String(),
          'startTime': t.startTime?.toIso8601String(),
          'endTime': t.endTime?.toIso8601String(),
          'parentId': t.parentId,
          'tags': taskState.tagsOf(t.id),
          'createdAt': t.createdAt.toIso8601String(),
        }).toList();

    final json = const JsonEncoder.withIndent('  ').convert({
      'exportedAt': DateTime.now().toIso8601String(),
      'taskCount': tasks.length,
      'tasks': tasks,
    });

    final dir = await getApplicationSupportDirectory();
    final fileName = 'vibetasking_export_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json';
    final file = File(p.join(dir.path, fileName));
    await file.writeAsString(json);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('已导出到: ${file.path}'),
      duration: const Duration(seconds: 5),
      action: SnackBarAction(
        label: '打开目录',
        onPressed: () {
          Process.run('explorer', [dir.path]);
        },
      ),
    ));
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

class _ShortcutRow extends StatelessWidget {
  final String shortcut;
  final String description;
  const _ShortcutRow(this.shortcut, this.description);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(shortcut,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
          ),
          const SizedBox(width: 12),
          Text(description),
        ],
      ),
    );
  }
}
