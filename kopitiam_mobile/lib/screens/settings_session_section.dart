import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/device_session_service.dart';
import '../services/local_auth_service.dart';
import 'login_screen.dart';

class SettingsSessionSection extends StatefulWidget {
  final Map<String, dynamic> session;

  const SettingsSessionSection({super.key, required this.session});

  @override
  State<SettingsSessionSection> createState() => _SettingsSessionSectionState();
}

class _SettingsSessionSectionState extends State<SettingsSessionSection> {
  Timer? _expiryTimer;
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    _expiryTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _enforceOfflineExpiry(),
    );
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _enforceOfflineExpiry(),
    );
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }

  Future<void> _enforceOfflineExpiry() async {
    if (!mounted || !LocalAuthService.offlineSessionExpired(widget.session)) {
      return;
    }
    await _clearLocalSession();
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
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar dari Kopitiam?'),
        content: const Text('Sesi perangkat dan akses offline akan dihapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _loggingOut = true);
    try {
      await ApiService.logoutPerangkat(
        token: (widget.session['token'] ?? '').toString(),
      );
    } catch (_) {
      await DeviceSessionService.clear();
    } finally {
      await _clearLocalSession();
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _clearLocalSession() async {
    await DeviceSessionService.clear();
    await LocalAuthService.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  @override
  Widget build(BuildContext context) {
    final offline = widget.session['offlineLogin'] == true;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(top: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Akun & Sesi',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              offline
                  ? 'Mode offline aktif, maksimal 24 jam sejak verifikasi online.'
                  : 'Keluar akan mencabut token perangkat dan akses offline.',
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _loggingOut ? null : _logout,
                icon: _loggingOut
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.logout_rounded),
                label: Text(_loggingOut ? 'Keluar...' : 'Log out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFDC2626),
                  side: const BorderSide(color: Color(0xFFFCA5A5)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
