import 'dart:async';
import 'package:flutter/services.dart';

class DeviceSyncService {
  static const MethodChannel _channel = MethodChannel('com.brainvent.app/device_sync');

  /// 🔒 将待办事项一键同步到本地系统提醒事项 (iOS Reminders)
  static Future<bool> syncReminders(List<String> items) async {
    if (items.isEmpty) return false;
    try {
      final bool success = await _channel.invokeMethod('syncReminders', {
        'items': items,
      });
      return success;
    } on PlatformException catch (_) {
      rethrow;
    }
  }

  /// ⚡ 从 Native 侧获取冷启动/热启动唤起 App 的 URL Scheme
  static Future<String?> getLaunchUrl() async {
    try {
      final String? url = await _channel.invokeMethod('getLaunchUrl');
      return url;
    } on PlatformException catch (_) {
      return null;
    }
  }

  /// 🧠 开启/关闭 ADHD 专注脑波催化音 (8Hz Alpha 双耳差频正弦波发生器)
  static Future<void> toggleFocusSound(bool play) async {
    try {
      await _channel.invokeMethod('toggleFocusSound', {
        'play': play,
      });
    } on PlatformException catch (_) {
      // Ignore errors
    }
  }
}
