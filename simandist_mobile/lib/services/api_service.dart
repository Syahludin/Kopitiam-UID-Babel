import 'dart:convert';

import 'package:http/http.dart' as http;

import 'device_session_service.dart';

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://script.google.com/macros/s/AKfycbxi45JX9sm_sgeLvXzI6KZsvJAlzaWhjtfT6p2W51vqwvp-TY7gAsXC9PA-Q_HZYp0o3Q/exec',
  );

  static const _redirectCodes = {301, 302, 303, 307, 308};

  static Future<http.Response> _getAppsScript(
    Uri initialUri, {
    Duration timeout = const Duration(seconds: 90),
  }) async {
    final client = http.Client();
    var current = initialUri;
    final visited = <String>{};
    try {
      for (var hop = 0; hop < 8; hop++) {
        if (!visited.add(current.toString())) {
          throw StateError('Redirect API berulang pada alamat yang sama.');
        }
        final request = http.Request('GET', current)
          ..followRedirects = false
          ..headers['Accept'] = 'application/json'
          ..headers['Cache-Control'] = 'no-cache';
        final streamed = await client.send(request).timeout(timeout);
        final response = await http.Response.fromStream(streamed);
        if (!_redirectCodes.contains(response.statusCode)) return response;
        final location = response.headers['location'];
        if (location == null || location.trim().isEmpty) {
          throw StateError('API mengirim redirect tanpa alamat tujuan.');
        }
        current = current.resolve(location.trim());
      }
      throw StateError('Redirect API terlalu banyak.');
    } finally {
      client.close();
    }
  }

  static Future<http.Response> _postAppsScript(
    Map<String, dynamic> payload,
  ) async {
    final client = http.Client();
    const timeout = Duration(seconds: 120);
    try {
      final uri = Uri.parse(baseUrl);
      final request = http.Request('POST', uri)
        ..followRedirects = false
        ..headers['Accept'] = 'application/json'
        ..headers['Content-Type'] = 'application/json'
        ..headers['Cache-Control'] = 'no-store'
        ..body = jsonEncode(payload);
      final streamed = await client.send(request).timeout(timeout);
      var response = await http.Response.fromStream(streamed);
      var hop = 0;
      while (_redirectCodes.contains(response.statusCode) && hop < 5) {
        final location = response.headers['location'];
        if (location == null || location.trim().isEmpty) break;
        response = await client
            .get(
              uri.resolve(location.trim()),
              headers: const {
                'Accept': 'application/json',
                'Cache-Control': 'no-store',
              },
            )
            .timeout(timeout);
        hop++;
      }
      return response;
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
  ) async => _decode(await _postAppsScript(payload));

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
  ) => _postMap({'action': 'syncWoInsjar', 'token': token, 'rows': rows});

  static Future<Map<String, dynamic>> syncTemuan(
    String token,
    Map<String, dynamic> row,
  ) => _postMap({'action': 'syncTemuanInspeksi', 'token': token, 'row': row});

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
