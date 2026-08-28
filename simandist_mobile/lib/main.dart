import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/login_screen.dart';
import 'screens/settings_session_section.dart';
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
      builder: (context, child) => _SessionGuard(child: child!),
    );
  }
}

class _SessionGuard extends StatefulWidget {
  final Widget child;

  const _SessionGuard({required this.child});

  @override
  State<_SessionGuard> createState() => _SessionGuardState();
}

class _SessionGuardState extends State<_SessionGuard>
    with WidgetsBindingObserver {
  static const _sessionKeys = [
    'token',
    'deviceToken',
    'username',
    'role',
    'kodeUiw',
    'kodeUp3',
    'kodeUlp',
    'ulp',
    'bidang',
    'tim',
    'subTim',
    'aksesMenu',
  ];

  Timer? _timer;
  bool _checking = false;
  bool _settingsSelected = false;
  Map<String, dynamic> _session = const {};

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

  Future<void> _selectBottomMenu(PointerUpEvent event) async {
    final size = MediaQuery.sizeOf(context);
    if (event.position.dy < size.height - 110) return;
    final index = (event.position.dx / (size.width / 3)).floor().clamp(0, 2);
    if (index != 2) {
      if (_settingsSelected && mounted) {
        setState(() {
          _settingsSelected = false;
          _session = const {};
        });
      }
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final session = <String, dynamic>{
      for (final key in _sessionKeys) key: prefs.getString(key) ?? '',
      'offlineLogin': prefs.getBool('offlineLogin') ?? false,
      'offlineExpiresAt': prefs.getString('offlineExpiresAt') ?? '',
    };
    if (!mounted || session['username'].toString().isEmpty) return;
    setState(() {
      _settingsSelected = true;
      _session = session;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerUp: _selectBottomMenu,
    child: Stack(
      children: [
        widget.child,
        if (_settingsSelected)
          Positioned(
            left: 18,
            right: 18,
            bottom: 88,
            child: Material(
              color: Colors.transparent,
              child: SettingsSessionSection(session: _session),
            ),
          ),
      ],
    ),
  );
}
