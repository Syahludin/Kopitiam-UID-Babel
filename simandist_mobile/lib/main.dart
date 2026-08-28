import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/login_screen.dart';
import 'services/device_session_service.dart';
import 'services/local_auth_service.dart';

void main() {
  runApp(const SiManDistApp());
}

class SiManDistApp extends StatelessWidget {
  const SiManDistApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SiManDist Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF004D8C)),
      ),
      home: const LoginScreen(),
      builder: (context, child) => _OfflineExpiryGuard(child: child!),
    );
  }
}

class _OfflineExpiryGuard extends StatefulWidget {
  final Widget child;

  const _OfflineExpiryGuard({required this.child});

  @override
  State<_OfflineExpiryGuard> createState() => _OfflineExpiryGuardState();
}

class _OfflineExpiryGuardState extends State<_OfflineExpiryGuard>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _check());
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (_checking || !mounted) return;
    _checking = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final offline = prefs.getBool('offlineLogin') ?? false;
      final expiresAt = DateTime.tryParse(
        prefs.getString('offlineExpiresAt') ?? '',
      )?.toUtc();
      if (!offline ||
          (expiresAt != null && DateTime.now().toUtc().isBefore(expiresAt))) {
        return;
      }
      await DeviceSessionService.clear();
      await LocalAuthService.clear();
      await prefs.clear();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (_) => false,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Login offline berakhir setelah 24 jam. Silakan login online.',
          ),
        ),
      );
    } finally {
      _checking = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
