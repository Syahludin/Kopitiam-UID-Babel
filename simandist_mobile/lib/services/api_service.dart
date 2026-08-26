import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://script.google.com/macros/s/AKfycbxi45JX9sm_sgeLvXzI6KZsvJAlzaWhjtfT6p2W51vqwvp-TY7gAsXC9PA-Q_HZYp0o3Q/exec',
  );

  static Future<http.Response> _postAppsScriptJson(
    Map<String, dynamic> payload, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
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
    return _decode(await _postAppsScriptJson({
      'action': 'login',
      'username': username,
      'password': password,
    }));
  }

  static Future<Map<String, dynamic>> cekSesi(String token) async {
    final uri = Uri.parse('$baseUrl?mobile=1&action=cekSesi&token=${Uri.encodeComponent(token)}');
    return _decode(await http.get(uri).timeout(const Duration(seconds: 15)));
  }

  static Future<Map<String, dynamic>> logout(String token) async {
    final uri = Uri.parse('$baseUrl?mobile=1&action=logout&token=${Uri.encodeComponent(token)}');
    return _decode(await http.get(uri).timeout(const Duration(seconds: 15)));
  }
}
