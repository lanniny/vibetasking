import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// 应用级设置（持久化到 JSON）
class AppSettings {
  bool enableTimeScheduling;
  String themeMode; // system / light / dark

  AppSettings({
    this.enableTimeScheduling = false,
    this.themeMode = 'system',
  });

  AppSettings copyWith({bool? enableTimeScheduling, String? themeMode}) {
    return AppSettings(
      enableTimeScheduling: enableTimeScheduling ?? this.enableTimeScheduling,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  Map<String, dynamic> toJson() => {
        'enableTimeScheduling': enableTimeScheduling,
        'themeMode': themeMode,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      enableTimeScheduling: json['enableTimeScheduling'] as bool? ?? false,
      themeMode: json['themeMode'] as String? ?? 'system',
    );
  }

  static Future<AppSettings> load() async {
    final file = await _settingsFile();
    if (!await file.exists()) return AppSettings();
    try {
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return AppSettings.fromJson(json);
    } catch (_) {
      return AppSettings();
    }
  }

  Future<void> save() async {
    final file = await _settingsFile();
    await file.writeAsString(jsonEncode(toJson()));
  }

  static Future<File> _settingsFile() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'app_settings.json'));
  }
}
