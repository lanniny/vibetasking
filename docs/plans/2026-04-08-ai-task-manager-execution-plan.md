# VibeTasKing 执行计划

> 冻结于 2026-04-08 | 内部等级: L (串行执行)

## 执行策略

单代理串行执行，按 Phase 顺序推进。每个 Phase 完成后验证再进入下一个。

## Phase 1: 项目骨架搭建

**目标**: 创建 Flutter 项目、配置依赖、建立目录结构

**步骤**:
1. `flutter create` 创建桌面项目
2. 配置 `pubspec.yaml` 核心依赖
3. 建立分层目录结构 (data/domain/presentation)
4. 配置 Windows 桌面支持

**依赖包**:
- `drift` + `sqlite3_flutter_libs` — 数据库
- `flutter_bloc` — 状态管理
- `http` — AI API 调用
- `dart_openai` 或自写抽象层 — AI Provider
- `uuid` — ID 生成
- `intl` — 日期格式化
- `json_annotation` + `json_serializable` — JSON 序列化

**验证**: `flutter run -d windows` 能启动空白应用

## Phase 2: 数据层 (Drift + SQLite)

**目标**: 实现完整数据模型和仓储层

**步骤**:
1. 定义 Drift 表: tasks, tags, task_tags, chat_messages
2. 编写 Database 类和 DAO
3. 实现 TaskRepository (CRUD + 查询)
4. 实现 ChatRepository
5. 实现 TagRepository
6. 运行 `build_runner` 生成代码

**验证**: 单元测试 — 创建/查询/更新/删除任务

## Phase 3: AI Provider 抽象层

**目标**: 统一多 AI Provider 接口

**步骤**:
1. 定义 `AIProvider` 抽象接口
2. 实现 OpenAI 兼容 Provider (覆盖 OpenAI/自定义)
3. 实现 Claude Provider
4. 实现 Ollama Provider
5. 实现 Provider 配置管理 (JSON 持久化)
6. 定义 Task 解析 Prompt 模板 (系统提示词)
7. 实现 AI → 结构化任务解析器

**验证**: 调用任意 Provider 发送消息并解析返回

## Phase 4: BLoC 状态管理

**目标**: 连接数据层和UI层的状态管理

**步骤**:
1. `TaskBloc` — 任务 CRUD、筛选、排序
2. `ChatBloc` — 聊天消息管理、AI 调用
3. `SettingsBloc` — AI Provider 配置管理
4. `BoardBloc` — 看板拖拽状态

**验证**: BLoC 测试 — 事件触发正确状态变更

## Phase 5: UI — 聊天视图

**目标**: 实现核心的 AI 聊天界面

**步骤**:
1. 聊天消息列表 (气泡样式)
2. 输入框 + 发送按钮
3. AI 回复流式显示
4. 任务创建成功后的卡片内联展示
5. 连接 ChatBloc

**验证**: 输入自然语言 → AI 返回 → 任务自动创建并可在数据库中查到

## Phase 6: UI — 看板视图

**目标**: 拖拽看板

**步骤**:
1. 三列布局: 待办 / 进行中 / 已完成
2. 任务卡片组件 (标题、优先级色标、日期、标签)
3. 拖拽交互 (改变任务状态)
4. 连接 TaskBloc

**验证**: 拖拽卡片从"待办"到"进行中" → 数据库状态同步更新

## Phase 7: UI — 列表视图

**目标**: 表格式任务列表

**步骤**:
1. 数据表格组件
2. 列头排序 (优先级/日期/状态)
3. 筛选栏 (标签/状态)
4. 行内快捷操作 (状态切换/删除)

**验证**: 排序和筛选正确反映数据

## Phase 8: UI — 设置页面

**目标**: AI Provider 可视化配置

**步骤**:
1. Provider 列表页
2. 添加/编辑 Provider 表单
3. 连通性测试按钮
4. 活跃 Provider 切换

**验证**: 添加 Provider → 测试连通 → 切换使用

## Phase 9: 导航与主题

**目标**: 整合所有视图、统一主题

**步骤**:
1. 侧边栏导航 (Chat / Board / List / Settings)
2. 深色/浅色主题
3. 应用图标和窗口标题
4. 快捷键支持

**验证**: 完整导航流程、主题切换

## Phase 10: 集成测试与收尾

**目标**: 端到端验证

**步骤**:
1. 完整用户流程测试: 聊天 → 创建任务 → 看板查看 → 列表筛选
2. AI 拆解项目测试
3. Provider 切换测试
4. 错误处理和边界情况
5. 构建 Windows 可执行文件

**验证**: 6 条验收标准全部通过

## 回滚规则

每个 Phase 完成前在文件系统保留可恢复状态。如某 Phase 失败，回退到上一个 Phase 的稳定代码。

## 清理期望

每个 Phase 完成后:
- 删除临时文件
- 确保无未使用的导入
- 生成的代码已提交 build_runner 输出
