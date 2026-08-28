import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'device_session_service.dart';

class SessionBootstrapService {
  static const sessionKeys = [
    'token',
    'deviceToken',
    'username',
    'role',
    'kodeUiw',
    'kodeUp3',
    'kodeUlp',
    'ulp',
    'bidang',
    'tim',
    'subTim',
    'aksesMenu',
  ];

  /// Restores a saved device session. Online validation is preferred because
  /// it also issues a fresh short-lived API token. If the API is unreachable,
  /// the encrypted profile may be used for at most 24 hours after the last
  /// successful online validation.
  static Future<Map<String, dynamic>?> restore() async {
    final deviceToken = await DeviceSessionService.token();
    if (deviceToken.isEmpty) return null;

    try {
      final result = await ApiService.cekPerangkat();
      if (result['success'] != true) {
        await clearPreferencesOnly();
        await DeviceSessionService.clear();
        return null;
      }
      final session = Map<String, dynamic>.from(result);
      await DeviceSessionService.save(
        deviceToken: (session['deviceToken'] ?? deviceToken).toString(),
        profile: session,
      );
      await _savePreferences(session, onlineVerifiedAt: DateTime.now().toUtc());
      return session;
    } catch (_) {
      final cached = await DeviceSessionService.profile();
      final prefs = await SharedPreferences.getInstance();
      final verifiedAt = DateTime.tryParse(
        prefs.getString('sessionOnlineVerifiedAt') ?? '',
      )?.toUtc();
      final now = DateTime.now().toUtc();
      if (cached == null ||
          verifiedAt == null ||
          now.isBefore(verifiedAt) ||
          now.difference(verifiedAt) >= const Duration(days: 1)) {
        return null;
      }
      final session = Map<String, dynamic>.from(cached)
        ..['offlineLogin'] = true
        ..['offlineExpiresAt'] = verifiedAt
            .add(const Duration(days: 1))
            .toIso8601String();
      await _savePreferences(session);
      return session;
    }
  }

  static Future<void> saveOnlineLogin(Map<String, dynamic> session) async {
    await _savePreferences(session, onlineVerifiedAt: DateTime.now().toUtc());
  }

  static Future<void> _savePreferences(
    Map<String, dynamic> session, {
    DateTime? onlineVerifiedAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in sessionKeys) {
      await prefs.setString(key, (session[key] ?? '').toString());
    }
    final offline = session['offlineLogin'] == true;
    await prefs.setBool('offlineLogin', offline);
    if (offline) {
      await prefs.setString(
        'offlineExpiresAt',
        (session['offlineExpiresAt'] ?? '').toString(),
      );
    } else {
      await prefs.remove('offlineExpiresAt');
    }
    if (onlineVerifiedAt != null) {
      await prefs.setString(
        'sessionOnlineVerifiedAt',
        onlineVerifiedAt.toIso8601String(),
      );
    }
  }

  static Future<void> clearPreferencesOnly() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in sessionKeys) {
      await prefs.remove(key);
    }
    await prefs.remove('offlineLogin');
    await prefs.remove('offlineExpiresAt');
    await prefs.remove('sessionOnlineVerifiedAt');
  }
}
