import 'dart:io';

import 'api_service.dart';

class NetworkStatusService {
  static Future<bool> isOnline() async {
    try {
      final uri = Uri.parse(ApiService.baseUrl);
      if (uri.scheme != 'https' || uri.host.isEmpty) return false;
      final addresses = await InternetAddress.lookup(uri.host);
      return addresses.isNotEmpty && addresses.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
