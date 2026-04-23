# VibeTasKing

<div align="center">

**面向 Windows 桌面的 AI 任务管理器**

*和 AI 说你想做什么 → 任务自动创建、调度，甚至自动执行。*

[![Release](https://img.shields.io/github/v/release/lanniny/vibetasking?style=flat-square)](https://github.com/lanniny/vibetasking/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.41+-54C5F8?style=flat-square&logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Windows-0078D6?style=flat-square&logo=windows)](https://github.com/lanniny/vibetasking/releases)

[English](README.md) · [中文](#中文)

</div>

---

## 中文

### VibeTasKing 是什么？

VibeTasKing 是一款 Windows 桌面任务管理器，你只需**用自然语言描述想做的事**，AI 就会自动创建任务、设定优先级、排列时间，甚至通过 **Claude Code** 自动帮你执行任务。

### 功能一览

#### 核心任务管理

| 功能 | 说明 |
|------|------|
| **AI 聊天** | 用自然语言描述任务，AI 自动解析优先级、截止日期、子任务和标签 |
| **看板视图** | 拖拽式看板，支持「待办 / 进行中 / 已完成」三列 |
| **列表视图** | 可排序、可筛选的任务列表，支持全文搜索 |
| **时间线视图** | 周视图甘特图，支持时间块调度 |

#### v1.1.0 新增功能

| 功能 | 说明 |
|------|------|
| **账单记账** | 个人收支记录，自定义分类，饼图/柱状图/折线图可视化 |
| **Claude YOLO** | 任务卡片上的一键执行按钮，在真实终端窗口中启动 `claude --dangerously-skip-permissions` |

#### AI 与集成

- **多 AI 服务商** — 支持 OpenAI、Claude（Anthropic）、DeepSeek、Gemini、Ollama，以及所有兼容 OpenAI 格式的接口
- **Base URL 自动补全** — 忘记输入 `/v1` 时自动修正
- **AI 报告** — 一键生成每日/每周工作汇报
- **密钥加密** — API 密钥使用机器指纹加密存储，不以明文保存

#### 效率工具

- **深色模式** — 跟随系统 / 浅色 / 深色三档切换
- **键盘快捷键** — `Ctrl+N` 快速新建，`Ctrl+1`–`Ctrl+6` 切换视图
- **快速添加** — 任意界面按 `Ctrl+N` 即可创建任务

---

### 快速开始

#### 下载安装（推荐）

前往 [Releases 页面](https://github.com/lanniny/vibetasking/releases) 下载最新版本。

解压 ZIP 后直接运行 `vibetasking.exe`，**无需安装**。

#### 从源码构建

**前置条件：**
- Flutter SDK 3.41+
- Visual Studio 2022（需勾选"使用 C++ 的桌面开发"工作负载）

```bash
git clone https://github.com/lanniny/vibetasking.git
cd vibetasking/app
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build windows --release
```

构建产物：`app/build/windows/x64/runner/Release/vibetasking.exe`

---

### 配置 AI 服务商

1. 启动 VibeTasKing
2. 点击侧边栏的**设置**（或按 `Ctrl+6`）
3. 点击**添加服务商**
4. 填写 API Key、Base URL 和模型名称

**常用接口地址：**

| 服务商 | Base URL | 备注 |
|--------|----------|------|
| OpenAI | `https://api.openai.com/v1` | GPT-4o、o1 等 |
| Claude | `https://api.anthropic.com/v1` | Claude 3.5 Sonnet 等 |
| DeepSeek | `https://api.deepseek.com/v1` | 性价比高 |
| Gemini | `https://generativelanguage.googleapis.com/v1beta/openai` | |
| Ollama | `http://localhost:11434/v1` | 本地模型 |
| 自定义 | `https://your-domain.com/v1` | 任何 OpenAI 兼容接口 |

> **提示：** 如果 Base URL 写错了（比如没加 `/v1`），VibeTasKing 会自动尝试修正。

---

### Claude YOLO — 自动执行任务

Claude YOLO 让你把任务"外包"给 Claude Code，在独立终端窗口中全自动完成：

1. 在任务详情里设置**工作目录**（点击任务标题旁的铅笔图标）
2. 可选填写**AI 指令**，告诉 Claude 具体该怎么做
3. 点击任务卡片上的 ✨ 按钮，选择执行时机：
   - **立即执行** — 马上启动
   - **使用开始时间** — 在任务设定的开始时间自动触发
   - **自选时间** — 任意指定未来的日期和时间

Claude 会在新的 cmd 窗口中运行，你可以实时看到执行进度。完成后任务自动变为"已完成"，并在描述中追加执行摘要。

> **前提条件：** 需要在系统中安装 [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) 并确保可在 `PATH` 中找到。

---

### 账单记账

在任务管理的同时追踪个人收支：

- **月度总览** — 当月收入 / 支出 / 余额，支持前后翻月
- **明细记录** — 新增、编辑、删除账单，可关联到具体任务
- **分类管理** — 自定义收入/支出分类，支持 Emoji 图标和颜色
- **可视化图表**
  - 支出饼图（按分类占比）
  - 近 6 个月收支柱状图
  - 当月每日折线图

---

### 键盘快捷键

| 快捷键 | 功能 |
|--------|------|
| `Ctrl+N` | 快速新建任务 |
| `Ctrl+1` | 切换到聊天视图 |
| `Ctrl+2` | 切换到看板视图 |
| `Ctrl+3` | 切换到列表视图 |
| `Ctrl+4` | 切换到时间线 |
| `Ctrl+5` | 切换到账单 |
| `Ctrl+6` | 打开设置 |

---

### 技术栈

| 层级 | 技术 |
|------|------|
| 框架 | Flutter 3.41（Windows 桌面） |
| 状态管理 | flutter_bloc 9.x |
| 数据库 | SQLite（通过 Drift ORM，schema v4） |
| AI 集成 | 多 Provider 抽象层（OpenAI 兼容 + Claude API） |
| 图表 | fl_chart |
| 安全 | API 密钥使用机器指纹密钥加密 |

---

### 项目结构

```
app/lib/
├── core/
│   ├── ai_providers/     # AI 服务商实现（OpenAI 兼容 + Claude）
│   ├── config/           # 应用设置 & 密钥加密
│   ├── services/         # ClaudeYoloService（任务自动执行引擎）
│   └── theme/            # 亮色/暗色主题
├── data/
│   └── database/         # Drift 数据库（Tasks/Tags/Bills/BillCategories/Chat）
└── presentation/
    ├── blocs/             # TaskBloc、ChatBloc、BillBloc
    ├── pages/             # 聊天、看板、列表、时间线、账单、设置
    └── widgets/           # TaskCard、ClaudeYoloButton、BillChart 等
```

---

### 版本历史

#### v1.1.1（2026-04-22）
- 修复：pubspec 版本号与发布 tag 对齐
- 修复：定时 YOLO 任务在任务被删除时不再抛出未捕获异常
- 修复：默认账单分类（餐饮、工资等）增加删除保护
- 修复：删除任务失败时正确显示错误状态

#### v1.1.0（2026-04-22）
- 新增：账单记账功能（收支记录、分类管理、3 种图表）
- 新增：Claude YOLO 一键执行（真实终端窗口，支持立即/定时/自选时间）
- 新增：Base URL 自动补全 `/v1`
- 修复：BLoC 内存泄漏（每次主题切换不再重建 BLoC）
- 修复：任务/分类级联删除（消除 FK 约束错误）
- 修复：YOLO prompt 历史清理使用精确标记，不影响用户 Markdown 分割线

#### v1.0.0（2026-04-08）
- 首次发布：AI 聊天、看板、列表、时间线、多服务商 AI、深色模式

---

### 社区

VibeTasKing 最初在 **LINUX DO** 社区推出——感谢那里的每一位成员提供的早期反馈和讨论。

| 渠道 | 用途 |
|------|------|
| [LINUX DO](https://linux.do) | 中文讨论、使用技巧和反馈（主要社区） |
| [GitHub Issues](https://github.com/lanniny/vibetasking/issues) | 错误报告、功能请求和异步讨论 |

### 开源协议

[MIT License](LICENSE) — Copyright © 2026 lanniny
