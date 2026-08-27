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

  /// ContentService Apps Script memindahkan respons JSON ke googleusercontent.
  /// Redirect ditangani manual agar package http tidak menganggap rantainya loop.
  static Future<http.Response> _getAppsScript(
    Uri initialUri, {
    Duration timeout = const Duration(seconds: 30),
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
          throw StateError(
            'API mengirim redirect tanpa alamat tujuan (HTTP ${response.statusCode}).',
          );
        }
        current = current.resolve(location.trim());
      }
      throw StateError('Redirect API terlalu banyak. Periksa deployment Apps Script.');
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

  static Future<Map<String, dynamic>> loginPerangkat(
    String username,
    String password,
  ) async {
    final device = await DeviceSessionService.deviceName();
    final uri = Uri.parse(baseUrl).replace(
      queryParameters: {
        'action': 'loginPerangkat',
        'username': username,
        'password': password,
        'perangkat': device,
      },
    );
    final result = _decode(await _getAppsScript(uri));
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
      return {
        'success': false,
        'kode': 'TANPA_TOKEN',
        'message': 'Belum ada sesi perangkat.',
      };
    }
    final uri = Uri.parse(baseUrl).replace(
      queryParameters: {
        'action': 'cekPerangkat',
        'deviceToken': deviceToken,
      },
    );
    final result = _decode(await _getAppsScript(uri));
    if (result['success'] == true) {
      await DeviceSessionService.save(
        deviceToken: deviceToken,
        profile: result,
      );
    }
    return result;
  }

  static Future<Map<String, dynamic>> getMasterData(String token) async {
    final uri = Uri.parse(baseUrl).replace(
      queryParameters: {
        'action': 'getMasterData',
        'token': token,
      },
    );
    return _decode(
      await _getAppsScript(uri, timeout: const Duration(seconds: 90)),
    );
  }

  static Future<Map<String, dynamic>> logoutPerangkat({
    String token = '',
  }) async {
    final deviceToken = await DeviceSessionService.token();
    try {
      final uri = Uri.parse(baseUrl).replace(
        queryParameters: {
          'action': 'logoutPerangkat',
          'deviceToken': deviceToken,
          'token': token,
        },
      );
      return _decode(await _getAppsScript(uri));
    } finally {
      await DeviceSessionService.clear();
    }
  }

  static Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) =>
      loginPerangkat(username, password);

  static Future<Map<String, dynamic>> cekSesi(String token) => cekPerangkat();

  static Future<Map<String, dynamic>> logout(String token) =>
      logoutPerangkat(token: token);
}
