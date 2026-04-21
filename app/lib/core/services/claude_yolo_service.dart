// Copyright (c) 2026 lanniny. All rights reserved.
// Licensed under the MIT License. See LICENSE file in the project root.
//
// Claude YOLO 服务：一键调用本地 claude CLI 自动执行任务
// 使用 --dangerously-skip-permissions 模式，无需用户确认

import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:vibetasking/data/database/database.dart';

/// YOLO 执行结果
class YoloResult {
  final bool success;
  final String stdout;
  final String stderr;
  final int exitCode;
  final DateTime startedAt;
  final DateTime finishedAt;

  const YoloResult({
    required this.success,
    required this.stdout,
    required this.stderr,
    required this.exitCode,
    required this.startedAt,
    required this.finishedAt,
  });

  Duration get duration => finishedAt.difference(startedAt);
}

/// YOLO 事件（供 UI 订阅，弹窗通知等）
class YoloEvent {
  final int taskId;
  final String taskTitle;
  final YoloResult? result;
  final String? error;
  final YoloEventType type;

  const YoloEvent({
    required this.taskId,
    required this.taskTitle,
    required this.type,
    this.result,
    this.error,
  });
}

enum YoloEventType { started, completed, failed, scheduled, cancelled }

/// Claude YOLO 核心服务
class ClaudeYoloService {
  final AppDatabase _db;
  final Map<int, Timer> _timers = {};
  final Map<int, int> _runningPids = {}; // taskId -> PowerShell PID
  final Set<int> _activeSessions = {};
  final StreamController<YoloEvent> _eventController =
      StreamController<YoloEvent>.broadcast();

  ClaudeYoloService(this._db);

  /// 诊断日志：写入 %USERPROFILE%\vibetasking_yolo_debug.log
  static void _debugLog(String msg) => logDebug(msg);

  /// public 版本，供 UI 调用
  static void logDebug(String msg) {
    try {
      final home = Platform.environment['USERPROFILE'] ??
          Platform.environment['HOME'] ??
          Directory.current.path;
      final logFile = File('$home\\vibetasking_yolo_debug.log');
      final ts = DateTime.now().toIso8601String();
      logFile.writeAsStringSync('[$ts] $msg\n',
          mode: FileMode.append, flush: true);
    } catch (_) {}
  }

  /// 事件流（UI 订阅）
  Stream<YoloEvent> get events => _eventController.stream;

  /// 当前正在运行的任务 ID 集合
  Set<int> get runningTaskIds => _activeSessions.toSet();

  /// 当前有定时器的任务 ID 集合
  Set<int> get scheduledTaskIds => _timers.keys.toSet();

  /// 应用启动时恢复调度：扫描 DB 中 aiScheduledAt 未来的任务
  Future<void> restoreSchedules() async {
    final scheduled = await _db.getScheduledYoloTasks();
    final now = DateTime.now();
    for (final task in scheduled) {
      if (task.aiScheduledAt != null && task.aiScheduledAt!.isAfter(now)) {
        _scheduleTimer(task, task.aiScheduledAt!);
      } else if (task.aiScheduledAt != null) {
        // 过期任务：清理字段
        await _db.updateTask(TasksCompanion(
          id: Value(task.id),
          aiScheduledAt: const Value(null),
        ));
      }
    }
  }

  /// 立即执行
  Future<YoloResult> runImmediate(Task task) async {
    _debugLog('=== runImmediate called for task ${task.id}: ${task.title} ===');
    return _execute(task);
  }

  /// 使用任务的 startTime 调度
  Future<void> scheduleAtStartTime(Task task) async {
    if (task.startTime == null) {
      throw Exception('任务没有设置开始时间');
    }
    await scheduleAt(task, task.startTime!);
  }

  /// 自定义时间调度
  Future<void> scheduleAt(Task task, DateTime when) async {
    if (when.isBefore(DateTime.now())) {
      throw Exception('调度时间必须在未来');
    }
    // 持久化调度时间
    await _db.updateTask(TasksCompanion(
      id: Value(task.id),
      aiScheduledAt: Value(when),
    ));
    _scheduleTimer(task, when);
    _eventController.add(YoloEvent(
      taskId: task.id,
      taskTitle: task.title,
      type: YoloEventType.scheduled,
    ));
  }

  /// 取消调度
  Future<void> cancelSchedule(int taskId) async {
    _timers[taskId]?.cancel();
    _timers.remove(taskId);
    try {
      await _db.updateTask(TasksCompanion(
        id: Value(taskId),
        aiScheduledAt: const Value(null),
      ));
    } catch (_) {}
    // task 可能已被删除，容错
    String title = '任务 #$taskId';
    try {
      final task = await _db.getTaskById(taskId);
      title = task.title;
    } catch (_) {}
    _eventController.add(YoloEvent(
      taskId: taskId,
      taskTitle: title,
      type: YoloEventType.cancelled,
    ));
  }

  /// 停止正在运行的进程
  ///
  /// 注意：bat 方案下 launcher 开的 cmd 窗口 PID 无法从 Dart 拿到，
  /// 所以这里只标记为已停止；用户需手动关闭终端窗口以杀掉 claude 进程。
  /// 标记后轮询循环会中断，_execute 结束。
  Future<void> stopRunning(int taskId) async {
    _activeSessions.remove(taskId);
    _runningPids.remove(taskId);
  }

  /// 释放资源
  void dispose() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    for (final pid in _runningPids.values) {
      try {
        Process.run('taskkill', ['/F', '/T', '/PID', pid.toString()]);
      } catch (_) {}
    }
    _runningPids.clear();
    _activeSessions.clear();
    _eventController.close();
  }

  // ── 内部：定时器 ──

  void _scheduleTimer(Task task, DateTime when) {
    _timers[task.id]?.cancel();
    final delay = when.difference(DateTime.now());
    _timers[task.id] = Timer(delay, () async {
      _timers.remove(task.id);
      // 重新从 DB 读最新任务
      try {
        final freshTask = await _db.getTaskById(task.id);
        await _execute(freshTask);
      } catch (e) {
        _eventController.add(YoloEvent(
          taskId: task.id,
          taskTitle: task.title,
          type: YoloEventType.failed,
          error: '定时执行失败: $e',
        ));
      }
      // 清理 scheduledAt
      await _db.updateTask(TasksCompanion(
        id: Value(task.id),
        aiScheduledAt: const Value(null),
      ));
    });
  }

  // ── 内部：执行核心 ──

  Future<YoloResult> _execute(Task task) async {
    _debugLog('_execute START taskId=${task.id} title="${task.title}"');
    _activeSessions.add(task.id);
    _eventController.add(YoloEvent(
      taskId: task.id,
      taskTitle: task.title,
      type: YoloEventType.started,
    ));

    // 把整个执行流程包在 try-catch 里，捕获任何异常并写日志
    // （因为调用方不 await 这个方法，异常若不捕获会被 Dart 当 unhandled 吞掉）
    try {
      return await _executeCore(task);
    } catch (e, st) {
      _debugLog('_execute FATAL: $e\n$st');
      _activeSessions.remove(task.id);
      _runningPids.remove(task.id);
      _eventController.add(YoloEvent(
        taskId: task.id,
        taskTitle: task.title,
        type: YoloEventType.failed,
        error: '执行致命错误: $e',
      ));
      return YoloResult(
        success: false,
        stdout: '',
        stderr: 'FATAL: $e\n$st',
        exitCode: -1,
        startedAt: DateTime.now(),
        finishedAt: DateTime.now(),
      );
    }
  }

  Future<YoloResult> _executeCore(Task task) async {
    _debugLog('_executeCore: updating task to in_progress');

    // 状态：-> in_progress
    await _db.updateTask(TasksCompanion(
      id: Value(task.id),
      status: const Value('in_progress'),
      updatedAt: Value(DateTime.now()),
    ));
    _debugLog('_executeCore: updateTask OK');

    final startedAt = DateTime.now();
    final workingDir = _resolveWorkingDir(task.workingDir);
    _debugLog('_executeCore: workingDir resolved=$workingDir');
    final prompt = await _buildPrompt(task);
    _debugLog('workingDir=$workingDir promptLen=${prompt.length}');

    int exitCode = -1;
    bool success = false;
    String stdout = '';
    String stderr = '';

    // 准备临时文件：transcript 日志、marker 完成标记、pid 文件、prompt 内容
    final tempRoot = await getTemporaryDirectory();
    _debugLog('tempRoot=${tempRoot.path}');
    final sessionId =
        '${task.id}_${DateTime.now().millisecondsSinceEpoch}';
    final sessionDir =
        Directory(p.join(tempRoot.path, 'vibetasking_yolo', sessionId));
    await sessionDir.create(recursive: true);
    _debugLog('sessionDir=${sessionDir.path} created=${sessionDir.existsSync()}');

    final markerFile = File(p.join(sessionDir.path, 'done.marker'));
    final promptFile = File(p.join(sessionDir.path, 'prompt.txt'));
    final mainBatFile = File(p.join(sessionDir.path, 'run.bat'));
    final launcherFile = File(p.join(sessionDir.path, 'launcher.bat'));

    try {
      // 写入 prompt 到文件（UTF-8 无 BOM，claude 能正确读取）
      await promptFile.writeAsString(prompt);
      _debugLog('prompt.txt written: ${promptFile.path}');

      // 生成主 bat 脚本（纯 ASCII，避免任何编码问题）
      final mainBat = _buildMainBat(
        workingDir: workingDir,
        promptFilePath: promptFile.path,
        markerFilePath: markerFile.path,
      );
      // bat 文件用 ANSI 写入（Windows cmd 默认），确保 100% 兼容
      await mainBatFile.writeAsString(mainBat);
      _debugLog('run.bat written: ${mainBatFile.path}');
      _debugLog('run.bat content:\n$mainBat');

      // 生成 launcher.bat（用 start 开独立新 console 窗口）
      final launcherBat = _buildLauncherBat(
        mainBatPath: mainBatFile.path,
        workingDir: workingDir,
      );
      await launcherFile.writeAsString(launcherBat);
      _debugLog('launcher.bat content:\n$launcherBat');

      // 启动 launcher.bat（Process.run 阻塞但很快返回因为 launcher 里 start 后立即 exit）
      _debugLog('Spawning cmd.exe /c ${launcherFile.path}');
      try {
        final result = await Process.run(
          'cmd.exe',
          ['/c', launcherFile.path],
          workingDirectory: workingDir,
          runInShell: false,
          includeParentEnvironment: true,
        );
        _debugLog(
            'cmd exitCode=${result.exitCode}\nstdout=${result.stdout}\nstderr=${result.stderr}');
      } catch (e, st) {
        _debugLog('Process.run THREW: $e\n$st');
        rethrow;
      }

      // 轮询等待 marker 文件出现（最长 1 小时，超时视为失败）
      const maxWaitMinutes = 60;
      final deadline = DateTime.now()
          .add(const Duration(minutes: maxWaitMinutes));
      _debugLog('Waiting for marker file...');
      while (!markerFile.existsSync()) {
        if (!_activeSessions.contains(task.id)) {
          // 被用户手动停止
          stderr = '用户手动停止了执行';
          break;
        }
        if (DateTime.now().isAfter(deadline)) {
          stderr = '执行超时（$maxWaitMinutes 分钟）';
          break;
        }
        await Future.delayed(const Duration(seconds: 1));
      }
      _debugLog('Marker file detected');

      // 读取结果
      if (markerFile.existsSync()) {
        final markerContent = (await markerFile.readAsString()).trim();
        exitCode = int.tryParse(markerContent) ?? -1;
        success = exitCode == 0;
        stdout = 'Claude YOLO 执行完成，退出码: $exitCode\n'
            '详细输出请查看刚才的终端窗口。';
      }
    } catch (e, st) {
      _debugLog('_execute OUTER CATCH: $e\n$st');
      stderr = '启动 Claude YOLO 失败: $e\n请确认已安装 Claude Code 并在 PATH 中。';
      success = false;
    } finally {
      _runningPids.remove(task.id);
      _activeSessions.remove(task.id);
      // 清理临时文件（延迟 30 分钟，保证用户有时间看终端 + prompt.txt 被 claude 读完）
      // 长任务（如大型重构）可能需要很久才结束，30 秒太短会在 claude 还没读完 prompt 时就删文件
      Future.delayed(const Duration(minutes: 30), () async {
        try {
          if (sessionDir.existsSync()) {
            await sessionDir.delete(recursive: true);
          }
        } catch (_) {}
      });
    }

    final finishedAt = DateTime.now();
    final result = YoloResult(
      success: success,
      stdout: stdout,
      stderr: stderr,
      exitCode: exitCode,
      startedAt: startedAt,
      finishedAt: finishedAt,
    );

    // 结果四件套：
    // ① 输出 append 到描述
    final output = result.stdout.isNotEmpty ? result.stdout : result.stderr;
    final existingDesc = task.description ?? '';
    final timestamp = _formatDateTime(finishedAt);
    final section = '''

---
**🤖 Claude YOLO 执行 @ $timestamp** (${success ? "✅ 成功" : "❌ 失败"}，耗时 ${result.duration.inSeconds}s)

```
${_truncate(output, 3000)}
```
''';
    await _db.updateTask(TasksCompanion(
      id: Value(task.id),
      description: Value(existingDesc + section),
      // ④ 状态自动 → done（仅成功时）
      status: Value(success ? 'done' : 'todo'),
      aiLastRunAt: Value(finishedAt),
      updatedAt: Value(finishedAt),
    ));

    // ② 聊天记录
    await _db.insertMessage(ChatMessagesCompanion.insert(
      role: 'assistant',
      content: success
          ? '🤖 任务「${task.title}」已由 Claude YOLO 自动执行完成，耗时 ${result.duration.inSeconds}s 喵～'
          : '⚠️ 任务「${task.title}」Claude YOLO 执行失败（退出码 $exitCode）',
    ));

    // 广播事件（UI 弹窗由此驱动）
    _eventController.add(YoloEvent(
      taskId: task.id,
      taskTitle: task.title,
      type: success ? YoloEventType.completed : YoloEventType.failed,
      result: result,
      error: success ? null : result.stderr,
    ));

    return result;
  }

  // ── 辅助：脚本生成（纯 bat，避开 PowerShell 编码坑）──

  /// launcher.bat：调用 `start` 在新 console 窗口打开 run.bat
  /// 只有 ASCII 字符，保证 cmd 在任何 codepage 下都能正确解析
  String _buildLauncherBat({
    required String mainBatPath,
    required String workingDir,
  }) {
    return [
      '@echo off',
      'cd /d "$workingDir"',
      // start "" 第一个空 title 避免把 mainBatPath 当 title；这样 start 会用 bat 文件名做 title
      'start "" "$mainBatPath"',
      'exit',
    ].join('\r\n');
  }

  /// 主执行脚本 run.bat（纯 ASCII，无中文，避免任何编码问题）
  ///
  /// 流程：
  /// 1. chcp 65001 让 cmd 支持 UTF-8 显示（给 claude 输出用）
  /// 2. cd 到工作目录
  /// 3. 打印分隔符 + 时间（纯英文）
  /// 4. 执行 claude，stdin 来自 prompt 文件，stdout 直接显示到终端（用户实时看到进度）
  /// 5. 捕获 exit code 写入 marker 文件（通知主应用）
  /// 6. pause 等待用户按键关闭窗口
  String _buildMainBat({
    required String workingDir,
    required String promptFilePath,
    required String markerFilePath,
  }) {
    return [
      '@echo off',
      'chcp 65001 > nul',
      'title Claude YOLO',
      'cd /d "$workingDir"',
      '',
      'echo ==========================================',
      'echo  Claude YOLO',
      'echo  Working dir: %CD%',
      'echo  Time: %DATE% %TIME%',
      'echo ==========================================',
      'echo.',
      '',
      'REM Run claude with prompt from stdin',
      'claude --dangerously-skip-permissions -p < "$promptFilePath"',
      'set EXITCODE=%ERRORLEVEL%',
      '',
      'echo.',
      'echo ==========================================',
      'echo  Finished (exit code: %EXITCODE%)',
      'echo  Time: %DATE% %TIME%',
      'echo ==========================================',
      '',
      'REM Write completion marker for main app (use < NUL trick to avoid trailing space)',
      '<nul set /p ="%EXITCODE%" > "$markerFilePath"',
      '',
      'echo.',
      'echo Press any key to close this window...',
      'pause > nul',
    ].join('\r\n');
  }

  String _resolveWorkingDir(String? fromTask) {
    final fallback = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        Directory.current.path;
    if (fromTask == null || fromTask.trim().isEmpty) {
      return fallback;
    }
    final dir = Directory(fromTask);
    if (dir.existsSync()) return fromTask;
    _debugLog('WARNING: workingDir "$fromTask" does not exist, fallback to $fallback');
    return fallback;
  }

  /// 清理历史 YOLO 输出块，防止递归喂入（保留用户自己写的 Markdown ---）
  static String _stripYoloHistory(String description) {
    // 精确匹配 YOLO section 开头标记：`\n---\n**🤖 Claude YOLO`
    const marker = '\n---\n**🤖 Claude YOLO';
    final idx = description.indexOf(marker);
    if (idx < 0) return description.trim();
    return description.substring(0, idx).trim();
  }

  /// prompt 内容最大大小（避免极端长的描述拖慢 claude）
  static const int _maxPromptBytes = 100 * 1024; // 100KB

  Future<String> _buildPrompt(Task task) async {
    final buf = StringBuffer();
    buf.writeln('# 任务：${task.title}');
    buf.writeln();
    if (task.description != null && task.description!.trim().isNotEmpty) {
      // 过滤掉历史 YOLO 输出（避免递归喂入），但保留用户的合法 Markdown ---
      final cleanDesc = _stripYoloHistory(task.description!);
      if (cleanDesc.isNotEmpty) {
        buf.writeln('## 任务描述');
        buf.writeln(cleanDesc);
        buf.writeln();
      }
    }

    // 子任务
    final subTasks = await _db.getSubTasks(task.id);
    if (subTasks.isNotEmpty) {
      buf.writeln('## 子任务清单');
      for (final sub in subTasks) {
        final done = sub.status == 'done' ? 'x' : ' ';
        buf.writeln('- [$done] ${sub.title}');
      }
      buf.writeln();
    }

    // 元信息
    buf.writeln('## 元信息');
    buf.writeln('- 优先级：${task.priority}');
    if (task.dueDate != null) {
      buf.writeln('- 截止日期：${_formatDate(task.dueDate!)}');
    }
    buf.writeln();

    // 自定义 prompt 模板（追加）
    if (task.aiPrompt != null && task.aiPrompt!.trim().isNotEmpty) {
      buf.writeln('## 执行指令');
      buf.writeln(task.aiPrompt);
      buf.writeln();
    } else {
      buf.writeln('## 执行指令');
      buf.writeln('请完成上述任务，尽可能彻底并提供清晰的执行总结。');
    }

    var result = buf.toString();
    // 大小保护：超过 100KB 截断，避免极端情况
    final bytes = result.codeUnits.length;
    if (bytes > _maxPromptBytes) {
      result = '${result.substring(0, _maxPromptBytes)}\n\n[prompt 过长已截断，总长 $bytes 字节]';
    }
    return result;
  }

  String _formatDateTime(DateTime dt) {
    String p(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${p(dt.month)}-${p(dt.day)} ${p(dt.hour)}:${p(dt.minute)}:${p(dt.second)}';
  }

  String _formatDate(DateTime dt) {
    String p(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${p(dt.month)}-${p(dt.day)}';
  }

  String _truncate(String s, int max) {
    if (s.length <= max) return s;
    return '${s.substring(0, max)}\n...（输出被截断，总长 ${s.length} 字符）';
  }
}
