import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vibetasking/core/ai_providers/provider_manager.dart';
import 'package:vibetasking/core/theme/app_theme.dart';
import 'package:vibetasking/data/database/database.dart';
import 'package:vibetasking/presentation/blocs/chat/chat_bloc.dart';
import 'package:vibetasking/presentation/blocs/task/task_bloc.dart';
import 'package:vibetasking/presentation/blocs/task/task_event.dart';
import 'package:vibetasking/presentation/pages/board_page.dart';
import 'package:vibetasking/presentation/pages/chat_page.dart';
import 'package:vibetasking/presentation/pages/list_page.dart';
import 'package:vibetasking/presentation/pages/settings_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = AppDatabase();
  final providerManager = ProviderManager();
  await providerManager.load();

  runApp(VibeTasKingApp(db: db, providerManager: providerManager));
}

class VibeTasKingApp extends StatelessWidget {
  final AppDatabase db;
  final ProviderManager providerManager;

  const VibeTasKingApp({
    super.key,
    required this.db,
    required this.providerManager,
  });

  @override
  Widget build(BuildContext context) {
    final taskBloc = TaskBloc(db)..add(LoadTasks());

    return MultiBlocProvider(
      providers: [
        BlocProvider<TaskBloc>.value(value: taskBloc),
        BlocProvider<ChatBloc>(
          create: (_) =>
              ChatBloc(db, providerManager, taskBloc)..add(LoadMessages()),
        ),
      ],
      child: MaterialApp(
        title: 'VibeTasKing',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        home: MainShell(providerManager: providerManager),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  final ProviderManager providerManager;

  const MainShell({super.key, required this.providerManager});

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Row(
        children: [
          // 侧边栏
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (i) => setState(() => _selectedIndex = i),
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  Icon(Icons.bolt, color: theme.colorScheme.primary, size: 32),
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
            destinations: _navItems,
          ),
          const VerticalDivider(width: 1, thickness: 1),

          // 主内容区
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
        );
      default:
        return const ChatPage();
    }
  }
}
