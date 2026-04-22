# VibeTasKing — Flutter App

This directory contains the Flutter source code for VibeTasKing.

For the full project documentation see the [root README](../README.md) / [中文说明](../README_CN.md).

## Development Setup

**Prerequisites:** Flutter SDK 3.41+, Visual Studio 2022 with C++ desktop workload.

```bash
# Install dependencies
flutter pub get

# Generate Drift code (required after schema changes)
dart run build_runner build --delete-conflicting-outputs

# Run in debug mode
flutter run -d windows

# Build release
flutter build windows --release
```

## Database Schema

Managed by Drift ORM — schema version 4.

| Table | Purpose |
|-------|---------|
| `tasks` | Main task records (title, status, priority, YOLO fields) |
| `tags` | Tag definitions |
| `task_tags` | Many-to-many task↔tag |
| `chat_messages` | AI chat history |
| `bill_categories` | Income/expense categories (14 defaults) |
| `bills` | Income/expense records, linked to tasks optionally |

To modify the schema: edit `lib/data/database/database.dart`, increment `schemaVersion`, add migration in `onUpgrade`, then re-run `build_runner`.

## Architecture

```
BLoCs (TaskBloc / ChatBloc / BillBloc)
    ↓ events / states
Pages (ChatPage / BoardPage / ListPage / TimelinePage / BillPage / SettingsPage)
    ↓ widgets
TaskCard / ClaudeYoloButton / BillChart / AddBillDialog
    ↓ services
ClaudeYoloService  (bat-based process launcher)
AppDatabase        (Drift SQLite)
ProviderManager    (AI provider registry)
```

## Key Files

| File | Role |
|------|------|
| `lib/main.dart` | App entry, BLoC lifecycle, YOLO event listener |
| `lib/data/database/database.dart` | Full schema + all CRUD operations |
| `lib/core/services/claude_yolo_service.dart` | YOLO bat script generation & process management |
| `lib/core/ai_providers/` | OpenAI-compatible + Claude provider implementations |
| `lib/presentation/blocs/` | All BLoC state machines |
