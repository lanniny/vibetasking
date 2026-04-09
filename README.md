# VibeTasKing

AI-Powered Task Manager for Desktop

> Tell the AI what you want to do. Tasks get created, scheduled, and organized automatically.

## Features

- **AI Chat** - Describe tasks in natural language, AI creates them with priority, due date, and tags
- **Board View** - Drag-and-drop Kanban board (Todo / In Progress / Done)
- **List View** - Sortable, filterable task list with search
- **Timeline View** - Weekly timeline with time blocks (simplified Gantt chart)
- **Time Scheduling** - AI assigns specific time slots (09:00-10:30) when enabled
- **AI Reports** - One-click daily/weekly report generation
- **Multi-Provider** - Support OpenAI, Claude, Gemini, Ollama, and custom endpoints
- **Dark Mode** - System / Light / Dark theme switching
- **Data Export** - Export all tasks to JSON
- **Keyboard Shortcuts** - Ctrl+N (new task), Ctrl+1~5 (switch views)

## Screenshots

| Chat | Board | Timeline |
|------|-------|----------|
| AI creates tasks from conversation | Drag-and-drop Kanban | Weekly schedule view |

## Getting Started

### Download

Download the latest release from [Releases](https://github.com/lanniny/vibetasking/releases).

### Build from Source

**Prerequisites:** Flutter SDK 3.41+, Visual Studio 2022 with C++ desktop workload

```bash
git clone https://github.com/lanniny/vibetasking.git
cd vibetasking/app
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build windows --release
```

The built executable will be at `app/build/windows/x64/runner/Release/vibetasking.exe`.

### Configure AI Provider

1. Launch VibeTasKing
2. Go to **Settings** (sidebar)
3. Click **Add Provider**
4. Enter your API Key, Base URL, and Model name
5. Start chatting!

**Common Base URLs:**

| Provider | Base URL |
|----------|----------|
| OpenAI | `https://api.openai.com/v1` |
| Claude | `https://api.anthropic.com/v1` |
| DeepSeek | `https://api.deepseek.com/v1` |
| Ollama | `http://localhost:11434/v1` |

## Tech Stack

- **Framework:** Flutter Desktop (Windows)
- **State Management:** flutter_bloc
- **Database:** SQLite via Drift
- **AI Integration:** Multi-provider abstraction (OpenAI-compatible / Claude API)
- **Security:** API keys encrypted with machine-derived key

## Project Structure

```
app/lib/
  core/
    ai_providers/     # Multi-provider AI abstraction layer
    config/           # App settings & key encryption
    theme/            # Light/dark theme definitions
  data/
    database/         # Drift SQLite schema & DAOs
  presentation/
    blocs/            # BLoC state management (task, chat)
    pages/            # Chat, Board, List, Timeline, Settings
    widgets/          # Reusable UI components
```

## License

[MIT License](LICENSE) - Copyright (c) 2026 lanniny
