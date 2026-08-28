import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
                KopitiamLoading(size: 64),
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

/// Indikator memuat bermerek KOPITIAM.
///
/// Animasi berada di dalam berkas SVG, jadi widget ini tidak memerlukan
/// controller. Bila berkas gagal dimuat, indikator bawaan tetap tampil supaya
/// pengguna tidak melihat ruang kosong.
class KopitiamLoading extends StatelessWidget {
  final double size;
  final bool onDarkBackground;

  const KopitiamLoading({
    super.key,
    this.size = 48,
    this.onDarkBackground = false,
  });

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    onDarkBackground
        ? 'assets/icons/loading_dark.svg'
        : 'assets/icons/loading.svg',
    width: size,
    height: size,
    placeholderBuilder: (_) => SizedBox(
      width: size,
      height: size,
      child: const Center(
        child: CircularProgressIndicator(color: Color(0xFF0D5C82)),
      ),
    ),
  );
}
