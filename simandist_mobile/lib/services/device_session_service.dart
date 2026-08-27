import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DeviceSessionService {
  static const _storage = FlutterSecureStorage();
  static const _deviceTokenKey = 'simandist_device_token';
  static const _profileKey = 'simandist_device_profile';

  static Future<String> token() => _storage.read(key: _deviceTokenKey).then((v) => v ?? '');

  static Future<void> save({required String deviceToken, required Map<String, dynamic> profile}) async {
    await _storage.write(key: _deviceTokenKey, value: deviceToken);
    await _storage.write(key: _profileKey, value: jsonEncode(profile));
  }

  static Future<Map<String, dynamic>?> profile() async {
    final raw = await _storage.read(key: _profileKey);
    if (raw == null || raw.isEmpty) return null;
    try { final value = jsonDecode(raw); return value is Map ? Map<String, dynamic>.from(value) : null; } catch (_) { return null; }
  }

  static Future<String> deviceName() async {
    try { return '${Platform.operatingSystem} ${Platform.operatingSystemVersion}'; } catch (_) { return 'perangkat'; }
  }

  static Future<void> clear() async {
    await _storage.delete(key: _deviceTokenKey);
    await _storage.delete(key: _profileKey);
  }
}
