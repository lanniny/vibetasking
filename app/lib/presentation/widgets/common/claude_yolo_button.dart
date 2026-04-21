// Copyright (c) 2026 lanniny. All rights reserved.
// Licensed under the MIT License. See LICENSE file in the project root.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vibetasking/core/services/claude_yolo_service.dart';
import 'package:vibetasking/data/database/database.dart';

/// Claude YOLO 按钮 — 弹出 3 个执行选项
class ClaudeYoloButton extends StatelessWidget {
  final Task task;
  final ClaudeYoloService service;
  final bool compact;

  const ClaudeYoloButton({
    super.key,
    required this.task,
    required this.service,
    this.compact = true,
  });

  @override
  Widget build(BuildContext context) {
    final isRunning = service.runningTaskIds.contains(task.id);
    final isScheduled = service.scheduledTaskIds.contains(task.id);

    return PopupMenuButton<String>(
      tooltip: isRunning
          ? '正在执行...'
          : (isScheduled ? '已调度' : '一键 Claude YOLO'),
      icon: Icon(
        isRunning
            ? Icons.hourglass_top
            : (isScheduled ? Icons.schedule : Icons.auto_awesome),
        size: compact ? 18 : 20,
        color: isRunning
            ? Colors.orange
            : (isScheduled ? Colors.blue : Colors.purple),
      ),
      itemBuilder: (ctx) => [
        const PopupMenuItem(
          value: 'now',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.play_arrow, color: Colors.green),
            title: Text('立即执行'),
            subtitle: Text('现在就启动 Claude'),
            dense: true,
          ),
        ),
        PopupMenuItem(
          value: 'start_time',
          enabled: task.startTime != null &&
              task.startTime!.isAfter(DateTime.now()),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.access_time, color: Colors.blue),
            title: const Text('使用开始时间'),
            subtitle: Text(task.startTime == null
                ? '未设置开始时间'
                : (task.startTime!.isBefore(DateTime.now())
                    ? '开始时间已过'
                    : '将于 ${DateFormat('MM-dd HH:mm').format(task.startTime!)} 执行')),
            dense: true,
          ),
        ),
        const PopupMenuItem(
          value: 'pick_time',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.edit_calendar, color: Colors.purple),
            title: Text('自选时间'),
            subtitle: Text('弹窗选择具体时间'),
            dense: true,
          ),
        ),
        if (isScheduled)
          const PopupMenuItem(
            value: 'cancel',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.cancel, color: Colors.red),
              title: Text('取消调度'),
              dense: true,
            ),
          ),
        if (isRunning)
          const PopupMenuItem(
            value: 'stop',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.stop_circle, color: Colors.red),
              title: Text('标记停止'),
              subtitle: Text('请手动关闭终端窗口'),
              dense: true,
            ),
          ),
      ],
      onSelected: (value) async {
        ClaudeYoloService.logDebug('button onSelected=$value task=${task.id}');
        try {
          switch (value) {
            case 'now':
              _showSnack(context, '🚀 Claude YOLO 已启动：${task.title}');
              // 不 await，避免阻塞 UI（异常由 _execute 内部 catch）
              service.runImmediate(task);
              break;
            case 'start_time':
              await service.scheduleAtStartTime(task);
              if (!context.mounted) return;
              _showSnack(context,
                  '⏰ 已调度：${DateFormat('MM-dd HH:mm').format(task.startTime!)}');
              break;
            case 'pick_time':
              final picked = await _pickDateTime(context);
              if (picked == null || !context.mounted) return;
              await service.scheduleAt(task, picked);
              if (!context.mounted) return;
              _showSnack(context,
                  '⏰ 已调度：${DateFormat('MM-dd HH:mm').format(picked)}');
              break;
            case 'cancel':
              await service.cancelSchedule(task.id);
              if (!context.mounted) return;
              _showSnack(context, '🚫 已取消调度');
              break;
            case 'stop':
              await service.stopRunning(task.id);
              if (!context.mounted) return;
              _showSnack(context, '⏹️ 已标记停止，请手动关闭终端窗口');
              break;
          }
        } catch (e) {
          if (!context.mounted) return;
          _showSnack(context, '❌ ${e.toString()}');
        }
      },
    );
  }

  void _showSnack(BuildContext context, String msg) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<DateTime?> _pickDateTime(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(minutes: 10)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !context.mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
          DateTime.now().add(const Duration(minutes: 10))),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }
}
