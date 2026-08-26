import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Penyimpanan kredensial lokal untuk mode offline.
/// Password asli tidak pernah disimpan. Hanya hash + salt lokal yang disimpan
/// di Android Keystore / iOS Keychain melalui flutter_secure_storage.
class LocalAuthService {
  static const _storage = FlutterSecureStorage();
  static const _usernameKey = 'local_auth_username';
  static const _hashKey = 'local_auth_password_hash';
  static const _saltKey = 'local_auth_password_salt';
  static const _sessionKey = 'local_auth_session_json';

  static Future<void> saveAfterOnlineLogin({
    required String username,
    required String password,
    required Map<String, dynamic> profile,
  }) async {
    final salt = _randomSalt();
    final hash = _hash(password, salt);
    await _storage.write(key: _usernameKey, value: username.trim().toLowerCase());
    await _storage.write(key: _hashKey, value: hash);
    await _storage.write(key: _saltKey, value: salt);
    await _storage.write(key: _sessionKey, value: jsonEncode(profile));
  }

  static Future<Map<String, dynamic>?> verifyOffline({
    required String username,
    required String password,
  }) async {
    final savedUsername = await _storage.read(key: _usernameKey);
    final savedHash = await _storage.read(key: _hashKey);
    final salt = await _storage.read(key: _saltKey);
    final sessionRaw = await _storage.read(key: _sessionKey);
    if (savedUsername == null || savedHash == null || salt == null || sessionRaw == null) return null;
    if (savedUsername != username.trim().toLowerCase()) return null;
    if (_hash(password, salt) != savedHash) return null;
    try {
      final session = jsonDecode(sessionRaw);
      if (session is Map) return Map<String, dynamic>.from(session);
    } catch (_) {}
    return null;
  }

  static Future<void> clear() async {
    for (final key in [_usernameKey, _hashKey, _saltKey, _sessionKey]) {
      await _storage.delete(key: key);
    }
  }

  static String _hash(String password, String salt) {
    var value = '$salt:$password';
    for (var i = 0; i < 12000; i++) {
      value = sha256.convert(utf8.encode(value)).toString();
    }
    return value;
  }

  static String _randomSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }
}
