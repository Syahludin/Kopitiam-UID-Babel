import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static void _assertConfigured() {
    if (baseUrl.isEmpty || !baseUrl.endsWith('/exec')) {
      throw StateError('API belum dikonfigurasi. Jalankan dengan --dart-define=API_BASE_URL=URL_EXEC_APPS_SCRIPT');
    }
  }

  static Future<http.Response> _postAppsScriptJson(
    Map<String, dynamic> payload, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    _assertConfigured();
    final uri = Uri.parse('$baseUrl?mobile=1');
    final client = http.Client();
    try {
      final request = http.Request('POST', uri)
        ..followRedirects = false
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode(payload);
      var streamed = await client.send(request).timeout(timeout);
      var response = await http.Response.fromStream(streamed);
      var hops = 0;
      while ({301, 302, 303, 307, 308}.contains(response.statusCode) && hops < 5) {
        final location = response.headers['location'];
        if (location == null || location.isEmpty) break;
        response = await client.get(uri.resolve(location)).timeout(timeout);
        hops++;
      }
      return response;
    } finally {
      client.close();
    }
  }

  static Map<String, dynamic> _decode(http.Response response) {
    final body = response.body.trim();
    if (body.isEmpty) return {'success': false, 'message': 'Respons API kosong (HTTP ${response.statusCode}).'};
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return {'success': false, 'message': 'Format respons API tidak valid.'};
    } catch (_) {
      return {'success': false, 'message': 'Backend tidak mengirim JSON valid.'};
    }
  }

  static Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await _postAppsScriptJson({
      'action': 'login',
      'username': username,
      'password': password,
    });
    return _decode(response);
  }

  static Future<Map<String, dynamic>> cekSesi(String token) async {
    _assertConfigured();
    final uri = Uri.parse('$baseUrl?mobile=1&action=cekSesi&token=${Uri.encodeComponent(token)}');
    return _decode(await http.get(uri).timeout(const Duration(seconds: 15)));
  }

  static Future<Map<String, dynamic>> logout(String token) async {
    _assertConfigured();
    final uri = Uri.parse('$baseUrl?mobile=1&action=logout&token=${Uri.encodeComponent(token)}');
    return _decode(await http.get(uri).timeout(const Duration(seconds: 15)));
  }
}
