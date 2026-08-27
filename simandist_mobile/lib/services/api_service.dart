import 'dart:convert';

import 'package:http/http.dart' as http;

import 'device_session_service.dart';

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://script.google.com/macros/s/AKfycbxi45JX9sm_sgeLvXzI6KZsvJAlzaWhjtfT6p2W51vqwvp-TY7gAsXC9PA-Q_HZYp0o3Q/exec',
  );

  static Map<String, dynamic> _decode(http.Response response) {
    final body = response.body.trim();
    if (body.isEmpty) throw StateError('Respons API kosong (HTTP ${response.statusCode}).');
    final value = jsonDecode(body);
    if (value is Map) return Map<String, dynamic>.from(value);
    throw StateError('Format respons API tidak valid.');
  }

  static Future<Map<String, dynamic>> loginPerangkat(String username, String password) async {
    final device = await DeviceSessionService.deviceName();
    final uri = Uri.parse('$baseUrl?action=loginPerangkat&username=${Uri.encodeQueryComponent(username)}&password=${Uri.encodeQueryComponent(password)}&perangkat=${Uri.encodeQueryComponent(device)}');
    final result = _decode(await http.get(uri).timeout(const Duration(seconds: 30)));
    if (result['success'] == true && result['deviceToken'] != null) {
      await DeviceSessionService.save(deviceToken: result['deviceToken'].toString(), profile: result);
    }
    return result;
  }

  static Future<Map<String, dynamic>> cekPerangkat() async {
    final deviceToken = await DeviceSessionService.token();
    if (deviceToken.isEmpty) return {'success': false, 'kode': 'TANPA_TOKEN', 'message': 'Belum ada sesi perangkat.'};
    final uri = Uri.parse('$baseUrl?action=cekPerangkat&deviceToken=${Uri.encodeQueryComponent(deviceToken)}');
    final result = _decode(await http.get(uri).timeout(const Duration(seconds: 20)));
    if (result['success'] == true) await DeviceSessionService.save(deviceToken: deviceToken, profile: result);
    return result;
  }

  static Future<Map<String, dynamic>> logoutPerangkat({String token = ''}) async {
    final deviceToken = await DeviceSessionService.token();
    try {
      final uri = Uri.parse('$baseUrl?action=logoutPerangkat&deviceToken=${Uri.encodeQueryComponent(deviceToken)}&token=${Uri.encodeQueryComponent(token)}');
      return _decode(await http.get(uri).timeout(const Duration(seconds: 15)));
    } finally { await DeviceSessionService.clear(); }
  }

  static Future<Map<String, dynamic>> login(String username, String password) => loginPerangkat(username, password);
  static Future<Map<String, dynamic>> cekSesi(String token) => cekPerangkat();
  static Future<Map<String, dynamic>> logout(String token) => logoutPerangkat(token: token);
}
