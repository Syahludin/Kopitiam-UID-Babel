import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract final class BackgroundSyncService {
  static const _channel = MethodChannel(
    'id.co.uidbabel.kopitiam/data_sync_service',
  );
  static const _activeKey = 'foreground_data_sync_active';
  static const _labelKey = 'foreground_data_sync_label';

  static bool get supported => !kIsWeb && Platform.isAndroid;

  static Future<void> start(String label) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_activeKey, true);
    await prefs.setString(_labelKey, label);
    if (!supported) return;
    try {
      await _channel.invokeMethod<bool>('ensureNotificationPermission');
      await _channel.invokeMethod<void>('start', {'label': label});
    } on PlatformException {
      await prefs.setBool(_activeKey, false);
      rethrow;
    }
  }

  static Future<void> update(String label, {int? progress}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_labelKey, label);
    if (!supported) return;
    await _channel.invokeMethod<void>('update', {
      'label': label,
      'progress': progress ?? -1,
    });
  }

  static Future<void> stop() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeKey);
    await prefs.remove(_labelKey);
    if (!supported) return;
    try {
      await _channel.invokeMethod<void>('stop');
    } on PlatformException {
      // The Android service may already have stopped with the task.
    }
  }

  static Future<String?> interruptedLabel() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_activeKey) != true) return null;
    return prefs.getString(_labelKey);
  }
}
