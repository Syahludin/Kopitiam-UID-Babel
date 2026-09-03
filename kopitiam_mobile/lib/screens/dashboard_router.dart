import 'package:flutter/material.dart';

import 'dashboard_screen_impl.dart' as standard;
import 'dashboard_screen_insdu.dart' as insdu;

class DashboardScreen extends StatelessWidget {
  final Map<String, dynamic> sesi;

  const DashboardScreen({super.key, required this.sesi});

  bool get _isInsdu {
    final sub = '${sesi['subTim'] ?? sesi['tim'] ?? ''}'.toLowerCase();
    final username = '${sesi['username'] ?? ''}'.toLowerCase();
    return sub.contains('inspeksi gardu') ||
        sub.contains('insdu') ||
        username.contains('.insdu');
  }

  @override
  Widget build(BuildContext context) => _isInsdu
      ? insdu.DashboardScreen(sesi: sesi)
      : standard.DashboardScreen(sesi: sesi);
}
