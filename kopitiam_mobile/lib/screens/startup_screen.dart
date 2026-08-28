import 'package:flutter/material.dart';

import '../services/session_bootstrap_service.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  late final Future<Map<String, dynamic>?> _restore =
      SessionBootstrapService.restore();

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>?>(
    future: _restore,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF004D8C)),
                SizedBox(height: 16),
                Text(
                  'Memulihkan sesi...',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      }
      final session = snapshot.data;
      if (session == null) return const LoginScreen();
      return DashboardScreen(sesi: session);
    },
  );
}
