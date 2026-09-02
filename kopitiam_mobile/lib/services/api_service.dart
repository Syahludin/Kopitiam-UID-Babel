import 'dart:convert';

import 'package:http/http.dart' as http;

import 'device_session_service.dart';

class ApiService {
  static const String baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://script.google.com/macros/s/AKfycbxi45JX9sm_sgeLvXzI6KZsvJAlzaWhjtfT6p2W51vqwvp-TY7gAsXC9PA-Q_HZYp0o3Q/exec');
  static const _redirectCodes = {301, 302, 303, 307, 308};
  static const _appsScriptHost = 'script.google.com';
  static const _contentHost = 'script.googleusercontent.com';

  static Future<http.Response> _postAppsScript(Map<String, dynamic> payload) async {
    final client = http.Client(); const timeout = Duration(seconds: 120); final initialUri = Uri.parse(baseUrl);
    if (initialUri.scheme != 'https' || initialUri.host != _appsScriptHost) throw StateError('Alamat API Apps Script tidak valid.');
    try { final request = http.Request('POST', initialUri)..followRedirects = false..headers['Accept'] = 'application/json'..headers['Content-Type'] = 'application/json; charset=utf-8'..headers['Cache-Control'] = 'no-store'..body = jsonEncode(payload); final response = await http.Response.fromStream(await client.send(request).timeout(timeout)); if (!_redirectCodes.contains(response.statusCode)) return response; final location = response.headers['location']; if (location == null || location.trim().isEmpty) throw StateError('API mengirim redirect tanpa alamat tujuan.'); final contentUri = initialUri.resolve(location.trim()); if (contentUri.scheme != 'https' || contentUri.host != _contentHost) throw StateError('Redirect respons API menuju alamat yang tidak diizinkan.'); final contentRequest = http.Request('GET', contentUri)..followRedirects = false..headers['Accept'] = 'application/json'..headers['Cache-Control'] = 'no-store'; return await http.Response.fromStream(await client.send(contentRequest).timeout(timeout)); } finally { client.close(); }
  }
  static Map<String, dynamic> _decode(http.Response response) { final body = response.body.trim(); if (body.isEmpty) throw StateError('Respons API kosong (HTTP ${response.statusCode}).'); if (response.statusCode < 200 || response.statusCode >= 300) throw StateError('API gagal (HTTP ${response.statusCode}).'); final value = jsonDecode(body); if (value is Map) return Map<String, dynamic>.from(value); throw StateError('Format respons API tidak valid.'); }
  static Future<Map<String, dynamic>> _postMap(Map<String, dynamic> p) async => _decode(await _postAppsScript(p));
  static Future<Map<String, dynamic>> loginPerangkat(String u, String p) async { final d = await DeviceSessionService.deviceName(); final r = await _postMap({'action': 'loginPerangkat', 'username': u, 'password': p, 'perangkat': d}); if (r['success'] == true && r['deviceToken'] != null) await DeviceSessionService.save(deviceToken: r['deviceToken'].toString(), profile: r); return r; }
  static Future<Map<String, dynamic>> cekPerangkat() async { final d = await DeviceSessionService.token(); if (d.isEmpty) return {'success': false, 'kode': 'TANPA_TOKEN'}; return _postMap({'action': 'cekPerangkat', 'deviceToken': d}); }
  static Future<Map<String, dynamic>> getMasterData(String t) => _postMap({'action': 'getMasterData', 'token': t});
  static Future<Map<String, dynamic>> getWoInsjar(String t) => _postMap({'action': 'getWoInsjar', 'token': t});
  static Future<Map<String, dynamic>> getTemuan(String t, String k) => _postMap({'action': 'getTemuanInspeksi', 'token': t, 'kodeWo': k});
  static Future<Map<String, dynamic>> syncWoInsjar(String t, List<Map<String, dynamic>> r) => _postMap({'action': 'syncWoInsjar', 'token': t, 'rows': r});
  static Future<Map<String, dynamic>> syncTemuan(String t, Map<String, dynamic> r) => _postMap({'action': 'syncTemuanInspeksi', 'token': t, 'row': r});
  static Future<Map<String, dynamic>> getWoRow(String t) => _postMap({'action': 'getWoRow', 'token': t});
  static Future<Map<String, dynamic>> syncWoRow(String t, List<Map<String, dynamic>> r) => _postMap({'action': 'syncWoRow', 'token': t, 'rows': r});
  static Future<Map<String, dynamic>> getWoHarJar(String t) => _postMap({'action': 'getWoHarJar', 'token': t});
  static Future<Map<String, dynamic>> syncWoHarJar(String t, List<Map<String, dynamic>> r) => _postMap({'action': 'syncWoHarJar', 'token': t, 'rows': r});
  static Future<Map<String, dynamic>> getWoInsdu(String t) => _postMap({'action': 'getWoInsdu', 'token': t});
  static Future<Map<String, dynamic>> syncWoInsdu(String t, List<Map<String, dynamic>> r) => _postMap({'action': 'syncWoInsdu', 'token': t, 'rows': r});
  static Future<Map<String, dynamic>> logoutPerangkat({String token = ''}) async { final d = await DeviceSessionService.token(); try { return await _postMap({'action': 'logoutPerangkat', 'deviceToken': d, 'token': token}); } finally { await DeviceSessionService.clear(); } }
  static Future<Map<String, dynamic>> login(String u, String p) => loginPerangkat(u, p);
  static Future<Map<String, dynamic>> cekSesi(String t) => cekPerangkat();
  static Future<Map<String, dynamic>> logout(String t) => logoutPerangkat(token: t);
}
