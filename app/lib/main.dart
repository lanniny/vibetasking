// Copyright (c) 2026 lanniny. All rights reserved.
// Licensed under the MIT License. See LICENSE file in the project root.
// https://github.com/lanniny/vibetasking

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vibetasking/core/ai_providers/provider_manager.dart';
import 'package:vibetasking/core/config/app_settings.dart';
import 'package:vibetasking/core/services/claude_yolo_service.dart';
import 'package:vibetasking/core/theme/app_theme.dart';
import 'package:vibetasking/data/database/database.dart';
import 'package:vibetasking/presentation/blocs/chat/chat_bloc.dart';
import 'package:vibetasking/presentation/blocs/task/task_bloc.dart';
import 'package:vibetasking/presentation/widgets/common/claude_yolo_scope.dart';
import 'package:vibetasking/presentation/blocs/bill/bill_bloc.dart';
import 'package:vibetasking/presentation/blocs/bill/bill_event.dart' as bill_event;
import 'package:vibetasking/presentation/blocs/task/task_event.dart';
import 'package:vibetasking/presentation/pages/bill_page.dart';
import 'package:vibetasking/presentation/pages/board_page.dart';
import 'package:vibetasking/presentation/pages/chat_page.dart';
import 'package:vibetasking/presentation/pages/list_page.dart';
import 'package:vibetasking/presentation/pages/settings_page.dart';
import 'package:vibetasking/presentation/pages/timeline_page.dart';
import 'package:vibetasking/presentation/widgets/common/quick_add_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final db = AppDatabase();
    final providerManager = ProviderManager();
    await providerManager.load();
    final settings = await AppSettings.load();
    final yoloService = ClaudeYoloService(db);
    // 启动时恢复未来调度（关闭应用期间的调度会丢失，这里只恢复仍然合法的未来时间）
    await yoloService.restoreSchedules();
    runApp(VibeTasKingApp(
      db: db,
      providerManager: providerManager,
      initialSettings: settings,
      yoloService: yoloService,
    ));
  } catch (e, stack) {
    runApp(MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(32),
          child: SelectableText('启动错误:\n$e\n\n$stack',
              style: const TextStyle(fontSize: 14, color: Colors.red)),
        ),
      ),
    ));
  }
}

class VibeTasKingApp extends StatefulWidget {
  final AppDatabase db;
  final ProviderManager providerManager;
  final AppSettings initialSettings;
  final ClaudeYoloService yoloService;

  const VibeTasKingApp({
    super.key,
    required this.db,
    required this.providerManager,
    required this.initialSettings,
    required this.yoloService,
  });

  @override
  State<VibeTasKingApp> createState() => _VibeTasKingAppState();
}

class _VibeTasKingAppState extends State<VibeTasKingApp> {
  late ThemeMode _themeMode;
  late final TaskBloc _taskBloc;
  late final BillBloc _billBloc;
  late final ChatBloc _chatBloc;

  @override
  void initState() {
    super.initState();
    _themeMode = _parseThemeMode(widget.initialSettings.themeMode);
    // 关键：BLoCs 在 initState 一次性创建，避免 build() 里重建导致内存泄漏
    _taskBloc = TaskBloc(widget.db)..add(LoadTasks());
    _billBloc = BillBloc(widget.db)
      ..add(bill_event.LoadBills())
      ..add(bill_event.LoadCategories());
    _chatBloc =
        ChatBloc(widget.db, widget.providerManager, _taskBloc)
          ..setBillBloc(_billBloc)
          ..add(LoadMessages());
  }

  @override
  void dispose() {
    _taskBloc.close();
    _billBloc.close();
    _chatBloc.close();
    widget.yoloService.dispose();
    super.dispose();
  }

  ThemeMode _parseThemeMode(String mode) {
    switch (mode) {
      case 'light': return ThemeMode.light;
      case 'dark': return ThemeMode.dark;
      default: return ThemeMode.system;
    }
  }

  void _onThemeChanged(ThemeMode mode) {
    setState(() => _themeMode = mode);
  }

  @override
  Widget build(BuildContext context) {
    return ClaudeYoloScope(
      service: widget.yoloService,
      child: MultiBlocProvider(
        providers: [
          BlocProvider<TaskBloc>.value(value: _taskBloc),
          BlocProvider<BillBloc>.value(value: _billBloc),
          BlocProvider<ChatBloc>.value(value: _chatBloc),
        ],
        child: MaterialApp(
          title: 'VibeTasKing',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: _themeMode,
          home: _YoloEventListener(
            service: widget.yoloService,
            taskBloc: _taskBloc,
            child: MainShell(
              providerManager: widget.providerManager,
              onThemeChanged: _onThemeChanged,
            ),
          ),
        ),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  final ProviderManager providerManager;
  final ValueChanged<ThemeMode> onThemeChanged;

  const MainShell({
    super.key,
    required this.providerManager,
    required this.onThemeChanged,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  static const _navItems = [
    NavigationRailDestination(
      icon: Icon(Icons.chat_outlined),
      selectedIcon: Icon(Icons.chat),
      label: Text('聊天'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.view_kanban_outlined),
      selectedIcon: Icon(Icons.view_kanban),
      label: Text('看板'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.list_alt_outlined),
      selectedIcon: Icon(Icons.list_alt),
      label: Text('列表'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.timeline_outlined),
      selectedIcon: Icon(Icons.timeline),
      label: Text('时间线'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.receipt_long_outlined),
      selectedIcon: Icon(Icons.receipt_long),
      label: Text('账单'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: Text('设置'),
    ),
  ];

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    if (!ctrl) return;

    if (event.logicalKey == LogicalKeyboardKey.keyN) {
      QuickAddDialog.show(context);
    } else if (event.logicalKey == LogicalKeyboardKey.digit1) {
      setState(() => _selectedIndex = 0);
    } else if (event.logicalKey == LogicalKeyboardKey.digit2) {
      setState(() => _selectedIndex = 1);
    } else if (event.logicalKey == LogicalKeyboardKey.digit3) {
      setState(() => _selectedIndex = 2);
    } else if (event.logicalKey == LogicalKeyboardKey.digit4) {
      setState(() => _selectedIndex = 3);
    } else if (event.logicalKey == LogicalKeyboardKey.digit5) {
      setState(() => _selectedIndex = 4);
    } else if (event.logicalKey == LogicalKeyboardKey.digit6) {
      setState(() => _selectedIndex = 5);
    }
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyWrapper);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyWrapper);
    super.dispose();
  }

  bool _handleKeyWrapper(KeyEvent event) {
    _handleKey(event);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (i) => setState(() => _selectedIndex = i),
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.secondary,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.bolt, color: Colors.white, size: 24),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Vibe',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            trailing: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton.small(
                    onPressed: () => QuickAddDialog.show(context),
                    tooltip: '快速创建 (Ctrl+N)',
                    child: const Icon(Icons.add),
                  ),
                  const SizedBox(height: 8),
                  IconButton(
                    onPressed: () => Process.run(
                        'cmd', ['/c', 'start', 'https://github.com/lanniny/vibetasking']),
                    icon: const Icon(Icons.code, size: 18),
                    tooltip: 'GitHub',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            destinations: _navItems,
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            child: _buildPage(),
          ),
        ],
      ),
    );
  }

  Widget _buildPage() {
    switch (_selectedIndex) {
      case 0:
        return const ChatPage();
      case 1:
        return const BoardPage();
      case 2:
        return const ListPage();
      case 3:
        return const TimelinePage();
      case 4:
        return const BillPage();
      case 5:
        return SettingsPage(
          providerManager: widget.providerManager,
          onChanged: () => setState(() {}),
          onThemeChanged: widget.onThemeChanged,
        );
      default:
        return const ChatPage();
    }
  }
}

/// YOLO 事件监听器：显示 SnackBar 通知 + 刷新任务/聊天
class _YoloEventListener extends StatefulWidget {
  final ClaudeYoloService service;
  final TaskBloc taskBloc;
  final Widget child;

  const _YoloEventListener({
    required this.service,
    required this.taskBloc,
    required this.child,
  });

  @override
  State<_YoloEventListener> createState() => _YoloEventListenerState();
}

class _YoloEventListenerState extends State<_YoloEventListener> {
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.service.events.listen(_handleEvent);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _handleEvent(YoloEvent event) {
    // 刷新任务列表
    widget.taskBloc.add(LoadTasks());

    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    switch (event.type) {
      case YoloEventType.completed:
        messenger.showSnackBar(SnackBar(
          content: Text(
              '✅ Claude 已完成「${event.taskTitle}」（${event.result?.duration.inSeconds ?? 0}s）'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: '查看',
            textColor: Colors.white,
            onPressed: () {
              // 切到列表页
              _showOutputDialog(context, event);
            },
          ),
        ));
        break;
      case YoloEventType.failed:
        messenger.showSnackBar(SnackBar(
          content: Text('❌ 「${event.taskTitle}」执行失败'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: '详情',
            textColor: Colors.white,
            onPressed: () => _showOutputDialog(context, event),
          ),
        ));
        break;
      case YoloEventType.started:
      case YoloEventType.scheduled:
      case YoloEventType.cancelled:
        // 已在按钮处通知
        break;
    }
  }

  void _showOutputDialog(BuildContext ctx, YoloEvent event) {
    final output =
        event.result?.stdout.isNotEmpty == true ? event.result!.stdout : '';
    final err = event.result?.stderr ?? event.error ?? '';
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text(event.type == YoloEventType.completed
            ? '✅ 执行成功'
            : '❌ 执行失败'),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('任务: ${event.taskTitle}'),
                if (event.result != null)
                  Text('耗时: ${event.result!.duration.inSeconds}s'),
                const SizedBox(height: 12),
                if (output.isNotEmpty) ...[
                  const Text('输出:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SelectableText(output,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 12)),
                ],
                if (err.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('错误:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.red)),
                  SelectableText(err,
                      style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: Colors.red)),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
