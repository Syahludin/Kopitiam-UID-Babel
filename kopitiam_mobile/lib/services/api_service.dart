import 'dart:convert';

import 'package:http/http.dart' as http;

import 'device_session_service.dart';

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue:
        'https://script.google.com/macros/s/AKfycbxi45JX9sm_sgeLvXzI6KZsvJAlzaWhjtfT6p2W51vqwvp-TY7gAsXC9PA-Q_HZYp0o3Q/exec',
  );

  static const _redirectCodes = {301, 302, 303, 307, 308};
  static const _appsScriptHost = 'script.google.com';
  static const _contentHost = 'script.googleusercontent.com';

  static Future<http.Response> _postAppsScript(
    Map<String, dynamic> payload,
  ) async {
    final client = http.Client();
    const timeout = Duration(seconds: 120);
    final initialUri = Uri.parse(baseUrl);
    if (initialUri.scheme != 'https' || initialUri.host != _appsScriptHost) {
      throw StateError('Alamat API Apps Script tidak valid.');
    }

    try {
      final request = http.Request('POST', initialUri)
        ..followRedirects = false
        ..headers['Accept'] = 'application/json'
        ..headers['Content-Type'] = 'application/json; charset=utf-8'
        ..headers['Cache-Control'] = 'no-store'
        ..body = jsonEncode(payload);
      final streamed = await client.send(request).timeout(timeout);
      final response = await http.Response.fromStream(streamed);
      if (!_redirectCodes.contains(response.statusCode)) return response;

      final location = response.headers['location'];
      if (location == null || location.trim().isEmpty) {
        throw StateError('API mengirim redirect tanpa alamat tujuan.');
      }
      final contentUri = initialUri.resolve(location.trim());
      if (contentUri.scheme != 'https' || contentUri.host != _contentHost) {
        throw StateError('Redirect respons API menuju alamat yang tidak diizinkan.');
      }

      // doPost sudah dieksekusi pada request pertama. ContentService kemudian
      // memberikan URL sekali pakai yang memang hanya menerima GET untuk
      // mengambil JSON hasil eksekusi. Body, password, dan token tidak dikirim
      // ulang pada request kedua.
      final contentRequest = http.Request('GET', contentUri)
        ..followRedirects = false
        ..headers['Accept'] = 'application/json'
        ..headers['Cache-Control'] = 'no-store';
      final contentStream = await client.send(contentRequest).timeout(timeout);
      return http.Response.fromStream(contentStream);
    } finally {
      client.close();
    }
  }

  static Map<String, dynamic> _decode(http.Response response) {
    final body = response.body.trim();
    if (body.isEmpty) {
      throw StateError('Respons API kosong (HTTP ${response.statusCode}).');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('API gagal (HTTP ${response.statusCode}).');
    }
    final value = jsonDecode(body);
    if (value is Map) return Map<String, dynamic>.from(value);
    throw StateError('Format respons API tidak valid.');
  }

  static Future<Map<String, dynamic>> _postMap(
    Map<String, dynamic> payload,
  ) async =>
      _decode(await _postAppsScript(payload));

  static Future<Map<String, dynamic>> loginPerangkat(
    String username,
    String password,
  ) async {
    final device = await DeviceSessionService.deviceName();
    final result = await _postMap({
      'action': 'loginPerangkat',
      'username': username,
      'password': password,
      'perangkat': device,
    });
    if (result['success'] == true && result['deviceToken'] != null) {
      await DeviceSessionService.save(
        deviceToken: result['deviceToken'].toString(),
        profile: result,
      );
    }
    return result;
  }

  static Future<Map<String, dynamic>> cekPerangkat() async {
    final deviceToken = await DeviceSessionService.token();
    if (deviceToken.isEmpty) {
      return {'success': false, 'kode': 'TANPA_TOKEN'};
    }
    return _postMap({'action': 'cekPerangkat', 'deviceToken': deviceToken});
  }

  static Future<Map<String, dynamic>> getMasterData(String token) =>
      _postMap({'action': 'getMasterData', 'token': token});

  static Future<Map<String, dynamic>> getWoInsjar(String token) =>
      _postMap({'action': 'getWoInsjar', 'token': token});

  static Future<Map<String, dynamic>> getTemuan(String token, String kodeWo) =>
      _postMap({
        'action': 'getTemuanInspeksi',
        'token': token,
        'kodeWo': kodeWo,
      });

  static Future<Map<String, dynamic>> syncWoInsjar(
    String token,
    List<Map<String, dynamic>> rows,
  ) =>
      _postMap({'action': 'syncWoInsjar', 'token': token, 'rows': rows});

  static Future<Map<String, dynamic>> syncTemuan(
    String token,
    Map<String, dynamic> row,
  ) =>
      _postMap({'action': 'syncTemuanInspeksi', 'token': token, 'row': row});

  static Future<Map<String, dynamic>> logoutPerangkat({
    String token = '',
  }) async {
    final deviceToken = await DeviceSessionService.token();
    try {
      return await _postMap({
        'action': 'logoutPerangkat',
        'deviceToken': deviceToken,
        'token': token,
      });
    } finally {
      await DeviceSessionService.clear();
    }
  }

  static Future<Map<String, dynamic>> login(String username, String password) =>
      loginPerangkat(username, password);

  static Future<Map<String, dynamic>> cekSesi(String token) => cekPerangkat();

  static Future<Map<String, dynamic>> logout(String token) =>
      logoutPerangkat(token: token);
}
