import 'package:flutter/material.dart';

import '../services/role_provider.dart';
import 'dashboard_har_du.dart';
import 'dashboard_unified.dart' as unified;

class DashboardRouter {
  static bool canAccessC4a(Map<String, dynamic> sesi) =>
      RoleProvider.hasC4aAccess(sesi);
}

class DashboardScreen extends StatelessWidget {
  final Map<String, dynamic> sesi;

  const DashboardScreen({super.key, required this.sesi});

  @override
  Widget build(BuildContext context) {
    final identity =
        '${sesi['subTim'] ?? sesi['tim'] ?? ''} ${sesi['username'] ?? ''}'
            .toLowerCase();
    final harDu =
        identity.contains('har du') ||
        identity.contains('hardu') ||
        identity.contains('har gardu');
    if (harDu) return HarDuDashboardScreen(sesi: sesi);
    return unified.DashboardScreen(sesi: sesi);
  }
}
