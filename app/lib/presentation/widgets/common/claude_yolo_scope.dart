// Copyright (c) 2026 lanniny. All rights reserved.
// Licensed under the MIT License. See LICENSE file in the project root.

import 'package:flutter/material.dart';
import 'package:vibetasking/core/services/claude_yolo_service.dart';

/// 通过 InheritedWidget 把 ClaudeYoloService 提供给整棵树
class ClaudeYoloScope extends InheritedWidget {
  final ClaudeYoloService service;

  const ClaudeYoloScope({
    super.key,
    required this.service,
    required super.child,
  });

  static ClaudeYoloService? maybeOf(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ClaudeYoloScope>();
    return scope?.service;
  }

  static ClaudeYoloService of(BuildContext context) {
    final s = maybeOf(context);
    if (s == null) {
      throw Exception('ClaudeYoloScope not found in widget tree');
    }
    return s;
  }

  @override
  bool updateShouldNotify(ClaudeYoloScope oldWidget) =>
      oldWidget.service != service;
}
