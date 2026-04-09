import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vibetasking/core/ai_providers/provider_manager.dart';
import 'package:vibetasking/core/config/app_settings.dart';
import 'package:vibetasking/core/theme/app_theme.dart';
import 'package:vibetasking/data/database/database.dart';
import 'package:vibetasking/presentation/blocs/chat/chat_bloc.dart';
import 'package:vibetasking/presentation/blocs/task/task_bloc.dart';
import 'package:vibetasking/presentation/blocs/task/task_event.dart';
import 'package:vibetasking/presentation/pages/board_page.dart';
import 'package:vibetasking/presentation/pages/chat_page.dart';
import 'package:vibetasking/presentation/pages/list_page.dart';
import 'package:vibetasking/presentation/pages/settings_page.dart';
import 'package:vibetasking/presentation/widgets/common/quick_add_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final db = AppDatabase();
    final providerManager = ProviderManager();
    await providerManager.load();
    final settings = await AppSettings.load();
    runApp(VibeTasKingApp(
      db: db,
      providerManager: providerManager,
      initialSettings: settings,
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

  const VibeTasKingApp({
    super.key,
    required this.db,
    required this.providerManager,
    required this.initialSettings,
  });

  @override
  State<VibeTasKingApp> createState() => _VibeTasKingAppState();
}

class _VibeTasKingAppState extends State<VibeTasKingApp> {
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _themeMode = _parseThemeMode(widget.initialSettings.themeMode);
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
    final taskBloc = TaskBloc(widget.db)..add(LoadTasks());

    return MultiBlocProvider(
      providers: [
        BlocProvider<TaskBloc>.value(value: taskBloc),
        BlocProvider<ChatBloc>(
          create: (_) => ChatBloc(
              widget.db, widget.providerManager, taskBloc)
            ..add(LoadMessages()),
        ),
      ],
      child: MaterialApp(
        title: 'VibeTasKing',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: _themeMode,
        home: MainShell(
          providerManager: widget.providerManager,
          onThemeChanged: _onThemeChanged,
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
              child: FloatingActionButton.small(
                onPressed: () => QuickAddDialog.show(context),
                tooltip: '快速创建 (Ctrl+N)',
                child: const Icon(Icons.add),
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
