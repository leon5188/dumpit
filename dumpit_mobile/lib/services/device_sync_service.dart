import 'dart:async';
import 'package:flutter/services.dart';

class DeviceSyncService {
  static const MethodChannel _channel = MethodChannel('com.brainvent.app/device_sync');
  static final StreamController<String> _launchUrlController = StreamController<String>.broadcast();

  /// 🔗 App 已在运行时（热启动）被 Action Button/Shortcut 再次唤起时触发
  static Stream<String> get onLaunchUrl => _launchUrlController.stream;

  static bool _listenerAttached = false;
  static void _ensureListener() {
    if (_listenerAttached) return;
    _listenerAttached = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onLaunchUrl' && call.arguments is String) {
        _launchUrlController.add(call.arguments as String);
      }
    });
  }

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
    _ensureListener();
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
