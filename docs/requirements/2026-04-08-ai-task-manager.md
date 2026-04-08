# VibeTasKing — AI 驱动任务管理桌面应用

> 需求文档 | 冻结于 2026-04-08

## 1. 产品概述

VibeTasKing 是一款本地优先的桌面任务管理应用。用户通过自然语言聊天与 AI 交互，一键创建、编辑、拆解和安排任务。同时提供传统看板和列表视图，实现"对话即管理"的极简体验。

## 2. 核心功能

### 2.1 AI 聊天任务引擎
- 自然语言输入 → AI 自动解析为结构化任务
- 自动提取：任务标题、描述、优先级、截止日期、标签
- 项目拆解：描述一个项目 → AI 拆解为多个子任务并安排时间
- 任务编辑：通过对话修改已有任务属性
- 上下文感知：AI 了解当前任务列表状态

### 2.2 看板视图
- 按状态分列：待办 / 进行中 / 已完成
- 拖拽移动任务卡片
- 卡片显示：标题、优先级标记、截止日期、标签

### 2.3 列表视图
- 表格形式展示所有任务
- 支持按优先级、截止日期、创建时间排序
- 支持按标签、状态筛选

### 2.4 任务属性
- 标题（必填）
- 描述（可选，Markdown）
- 状态：todo / in_progress / done
- 优先级：urgent / high / medium / low
- 截止日期（可选）
- 标签（多个，自定义）
- 子任务（嵌套）
- 创建时间、更新时间

### 2.5 AI Provider 管理
- 支持多 Provider：OpenAI / Claude / Gemini / Ollama / 自定义
- 可视化配置界面：API Key、Base URL、Model Name
- 可切换当前活跃 Provider
- 连通性测试

## 3. 技术架构

```
┌──────────────────────────────────┐
│         Flutter Desktop UI       │
│  ┌───────┐ ┌───────┐ ┌────────┐ │
│  │ Chat  │ │ Board │ │  List  │ │
│  │ View  │ │ View  │ │  View  │ │
│  └───┬───┘ └───┬───┘ └───┬────┘ │
│      └─────────┼─────────┘      │
│           ┌────┴────┐           │
│           │ BLoC /  │           │
│           │ State   │           │
│           └────┬────┘           │
│      ┌─────────┼─────────┐     │
│  ┌───┴───┐ ┌───┴───┐ ┌──┴──┐  │
│  │ Task  │ │  AI   │ │ Set │  │
│  │ Repo  │ │Service│ │tings│  │
│  └───┬───┘ └───┬───┘ └──┬──┘  │
│      │         │        │     │
│  ┌───┴───┐ ┌───┴────┐ ┌┴───┐ │
│  │ Drift │ │Provider│ │JSON│ │
│  │SQLite │ │Abstract│ │File│ │
│  └───────┘ └────────┘ └────┘ │
└──────────────────────────────────┘
```

- **UI 层**: Flutter Widget (Chat / Board / List)
- **状态管理**: flutter_bloc
- **数据层**: Drift (SQLite ORM)
- **AI 层**: 多 Provider 抽象接口
- **配置**: 本地 JSON 文件存储 AI Provider 配置

## 4. 数据模型

### Task
| 字段 | 类型 | 说明 |
|------|------|------|
| id | int (auto) | 主键 |
| title | text | 任务标题 |
| description | text? | 描述 (Markdown) |
| status | text | todo/in_progress/done |
| priority | text | urgent/high/medium/low |
| due_date | datetime? | 截止日期 |
| parent_id | int? | 父任务ID（子任务） |
| created_at | datetime | 创建时间 |
| updated_at | datetime | 更新时间 |

### Tag
| 字段 | 类型 | 说明 |
|------|------|------|
| id | int (auto) | 主键 |
| name | text | 标签名 |
| color | text | 颜色 hex |

### TaskTag (关联表)
| 字段 | 类型 |
|------|------|
| task_id | int FK |
| tag_id | int FK |

### ChatMessage
| 字段 | 类型 | 说明 |
|------|------|------|
| id | int (auto) | 主键 |
| role | text | user/assistant |
| content | text | 消息内容 |
| created_at | datetime | 时间戳 |

### AIProvider (JSON配置)
| 字段 | 类型 | 说明 |
|------|------|------|
| id | string | 唯一标识 |
| name | string | 显示名 |
| type | string | openai/claude/gemini/ollama/custom |
| api_key | string | API密钥 |
| base_url | string | 端点地址 |
| model | string | 模型名 |
| is_active | bool | 是否当前使用 |

## 5. 非目标
- 多用户 / 团队协作
- 云端同步 / 部署
- 移动端适配

## 6. 验收标准
1. 用户输入"帮我创建一个明天截止的高优先级任务：完成项目报告" → 自动创建任务
2. 用户输入"帮我规划一个网站开发项目" → AI 拆解为 5+ 个子任务
3. 看板视图可拖拽改变任务状态
4. 列表视图可按优先级排序
5. 可配置并切换 AI Provider
6. Windows 桌面可正常运行
