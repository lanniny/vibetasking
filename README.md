# VibeTasKing

<div align="center">

**AI-Powered Task Manager for Windows Desktop**

*Talk to AI → Tasks get created, scheduled, and even executed automatically.*

[![Release](https://img.shields.io/github/v/release/lanniny/vibetasking?style=flat-square)](https://github.com/lanniny/vibetasking/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.41+-54C5F8?style=flat-square&logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Windows-0078D6?style=flat-square&logo=windows)](https://github.com/lanniny/vibetasking/releases)

[English](#english) · [中文](README_CN.md)

</div>

---

## English

### What is VibeTasKing?

VibeTasKing is a desktop task manager where you **describe what you want to do in plain language** and AI handles the rest — creating tasks, setting priorities, scheduling time slots, and even **executing them via Claude Code** automatically.

### Features

#### Core Task Management
| Feature | Description |
|---------|-------------|
| **AI Chat** | Describe tasks in natural language, AI creates them with priority, due date, subtasks, and tags |
| **Kanban Board** | Drag-and-drop board with Todo / In Progress / Done columns |
| **List View** | Sortable, filterable task list with full-text search |
| **Timeline** | Weekly Gantt-style view with time block scheduling |

#### New in v1.1.0
| Feature | Description |
|---------|-------------|
| **Bill Tracker** | Personal accounting — income/expense records, category management, pie/bar/line charts |
| **Claude YOLO** | One-click button on any task: launches `claude --dangerously-skip-permissions` in a real terminal window at a scheduled time |

#### AI & Integration
- **Multi-Provider** — OpenAI, Claude (Anthropic), DeepSeek, Gemini, Ollama, or any OpenAI-compatible endpoint
- **Auto URL Fix** — Automatically appends `/v1` if you forget it in the Base URL
- **AI Reports** — One-click daily/weekly report generation
- **Encrypted Keys** — API keys encrypted with a machine-derived key (never stored in plain text)

#### Productivity
- **Dark Mode** — System / Light / Dark theme
- **Keyboard Shortcuts** — `Ctrl+N` new task, `Ctrl+1`–`Ctrl+6` switch views
- **Quick Add** — `Ctrl+N` anywhere to instantly add a task

### Getting Started

#### Download (Recommended)

Download the latest release from the [Releases page](https://github.com/lanniny/vibetasking/releases).

Extract the ZIP and run `vibetasking.exe` — no installation required.

#### Build from Source

**Prerequisites:**
- Flutter SDK 3.41+
- Visual Studio 2022 with "Desktop development with C++" workload

```bash
git clone https://github.com/lanniny/vibetasking.git
cd vibetasking/app
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build windows --release
```

Built executable: `app/build/windows/x64/runner/Release/vibetasking.exe`

#### Configure AI Provider

1. Launch VibeTasKing
2. Open **Settings** (sidebar, or `Ctrl+6`)
3. Click **Add Provider**
4. Enter your API Key, Base URL, and Model name

**Common endpoints:**

| Provider | Base URL | Notes |
|----------|----------|-------|
| OpenAI | `https://api.openai.com/v1` | GPT-4o, o1, etc. |
| Claude | `https://api.anthropic.com/v1` | Claude 3.5 Sonnet etc. |
| DeepSeek | `https://api.deepseek.com/v1` | Cost-effective |
| Gemini | `https://generativelanguage.googleapis.com/v1beta/openai` | |
| Ollama | `http://localhost:11434/v1` | Local models |
| Custom | `https://your-domain.com/v1` | Any OpenAI-compatible API |

> **Tip:** If you accidentally omit `/v1`, VibeTasKing will auto-correct it.

### Claude YOLO — Automated Task Execution

Claude YOLO lets you delegate a task to Claude Code, which runs in its own terminal window:

1. Set a **Working Directory** on the task (Settings icon in task detail)
2. Optionally write a custom **AI Prompt** to guide Claude
3. Click the ✨ button on any task card → choose when to run:
   - **Run Now** — launches immediately
   - **Use Start Time** — fires at the task's scheduled start time
   - **Pick Time** — choose any future date/time

Claude opens in a real cmd window so you can watch progress. When it finishes, the task auto-updates to Done and a summary is appended to the description.

> **Requires:** [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed and available in `PATH`.

### Bill Tracker

Track personal income and expenses alongside your tasks:

- **Overview** — Monthly income / expense / balance summary with month navigation
- **Records** — Add, edit, delete entries; link bills to specific tasks
- **Categories** — Customizable income/expense categories with emoji icons and colors
- **Charts** — Expense breakdown pie chart, 6-month bar chart, daily line chart

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl+N` | Quick add task |
| `Ctrl+1` | Chat view |
| `Ctrl+2` | Kanban board |
| `Ctrl+3` | List view |
| `Ctrl+4` | Timeline |
| `Ctrl+5` | Bill tracker |
| `Ctrl+6` | Settings |

### Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter 3.41 (Windows Desktop) |
| State Management | flutter_bloc 9.x |
| Database | SQLite via Drift ORM (schema v4) |
| AI | Multi-provider abstraction (OpenAI-compatible + Claude API) |
| Charts | fl_chart |
| Security | Machine-derived key encryption for API keys |

### Project Structure

```
app/lib/
├── core/
│   ├── ai_providers/     # OpenAI-compatible + Claude provider implementations
│   ├── config/           # App settings & key encryption
│   ├── services/         # ClaudeYoloService (task execution engine)
│   └── theme/            # Light/dark theme tokens
├── data/
│   └── database/         # Drift schema (Tasks, Tags, Bills, BillCategories, Chat)
└── presentation/
    ├── blocs/             # TaskBloc, ChatBloc, BillBloc
    ├── pages/             # Chat, Board, List, Timeline, Bill, Settings
    └── widgets/           # TaskCard, ClaudeYoloButton, BillChart, etc.
```

### Changelog

#### v1.1.1 (2026-04-22)
- Fix: pubspec version number aligned with release tag
- Fix: Scheduled YOLO tasks no longer crash when the task is deleted while waiting
- Fix: Default bill categories (Dining, Salary, etc.) are now protected from deletion
- Fix: Delete task error state now surfaces correctly in the UI

#### v1.1.0 (2026-04-22)
- Feature: Bill Tracker — income/expense recording, category management, 3 chart types
- Feature: Claude YOLO — one-click task execution via Claude Code CLI with real terminal window
- Feature: Base URL auto-normalization (auto-appends `/v1`)
- Fix: BLoC memory leak (blocs no longer recreated on every theme change)
- Fix: Task/category cascade delete (FK constraint errors eliminated)
- Fix: YOLO prompt history stripping uses precise marker to preserve user Markdown

#### v1.0.0 (2026-04-08)
- Initial release: AI Chat, Kanban, List, Timeline, Multi-provider AI, Dark Mode

### Community

VibeTasKing was first launched on the **LINUX DO** community — thanks to every member there for early feedback and discussion.

| Channel | Purpose |
|---------|---------|
| [LINUX DO](https://linux.do) | Chinese discussion, tips, and feedback *(primary community)* |
| [GitHub Issues](https://github.com/lanniny/vibetasking/issues) | Bug reports, feature requests, and async discussion |

### License

[MIT License](LICENSE) — Copyright © 2026 lanniny
