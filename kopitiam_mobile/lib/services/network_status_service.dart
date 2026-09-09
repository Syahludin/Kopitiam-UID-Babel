import 'dart:async';
import 'dart:io';

import 'api_service.dart';

/// Mengecek keterjangkauan host API, bukan sekadar keberadaan Wi-Fi/data.
class NetworkStatusService {
  static Future<bool> isOnline({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    Socket? socket;
    try {
      final uri = Uri.parse(ApiService.baseUrl);
      if (uri.scheme != 'https' || uri.host.isEmpty) return false;
      socket = await Socket.connect(uri.host, uri.hasPort ? uri.port : 443)
          .timeout(timeout);
      return true;
    } catch (_) {
      return false;
    } finally {
      socket?.destroy();
    }
  }
}
