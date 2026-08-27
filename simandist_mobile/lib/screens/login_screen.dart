import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/local_auth_service.dart';
import 'dashboard_screen.dart';

class AppColors {
  static const navy950 = Color(0xFF071B30);
  static const navy900 = Color(0xFF0F172A);
  static const navy700 = Color(0xFF004D8C);
  static const navy100 = Color(0xFFD9F5FF);
  static const amber600 = Color(0xFFFFB800);
  static const neutral900 = Color(0xFF0F172A);
  static const neutral500 = Color(0xFF64748B);
  static const neutral300 = Color(0xFFCBD5E1);
  static const neutral200 = Color(0xFFE2E8F0);
  static const neutral100 = Color(0xFFF1F5F9);
  static const red600 = Color(0xFFDC2626);
  static const red100 = Color(0xFFFEE2E2);
  static const plnYellow = Color(0xFFFFDE00);
  static const plnRed = Color(0xFFE30613);
  static const safetyOrange = Color(0xFFF97316);
  static const safetyCream = Color(0xFFFFF7ED);
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  void _showSafetyWelcome(BuildContext context, Map<String, dynamic> sesi) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: AppColors.navy950.withValues(alpha: .72),
      builder: (_) => _SafetyWelcomeDialog(sesi: sesi),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned(top: 12, right: 20, child: _PlnBadge()),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: 132, height: 132, child: SvgPicture.asset('assets/icons/logo_app.svg')),
                    const SizedBox(height: 20),
                    const Text.rich(
                      TextSpan(children: [
                        TextSpan(text: 'SiMan', style: TextStyle(color: AppColors.navy900)),
                        TextSpan(text: 'Dist', style: TextStyle(color: AppColors.amber600)),
                      ]),
                      style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    const Text('Sistem Manajemen Distribusi', style: TextStyle(fontSize: 15, color: AppColors.neutral500)),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
                      decoration: BoxDecoration(color: AppColors.navy100, borderRadius: BorderRadius.circular(100)),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.location_on, size: 12, color: AppColors.amber600),
                        SizedBox(width: 6),
                        Text('PLN UID BABEL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: .5, color: AppColors.navy700)),
                      ]),
                    ),
                    const SizedBox(height: 44),
                    SizedBox(
                      width: 260,
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => _LoginSheet(onVerified: (sesi) => _showSafetyWelcome(context, sesi)),
                        ),
                        icon: const Icon(Icons.login, size: 18),
                        label: const Text('Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.navy700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          elevation: 4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Positioned(bottom: 20, left: 0, right: 0, child: Text('Sistem Manajemen Distribusi © 2026 · PLN UID Babel', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: AppColors.neutral500))),
          ],
        ),
      ),
    );
  }
}

class _PlnBadge extends StatelessWidget {
  const _PlnBadge();
  @override
  Widget build(BuildContext context) => Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(color: AppColors.plnYellow, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .15), blurRadius: 8, offset: const Offset(0, 3))]),
        child: const Icon(Icons.bolt, color: AppColors.plnRed, size: 28),
      );
}

class _LoginSheet extends StatefulWidget {
  final ValueChanged<Map<String, dynamic>> onVerified;
  const _LoginSheet({required this.onVerified});
  @override
  State<_LoginSheet> createState() => _LoginSheetState();
}

class _LoginSheetState extends State<_LoginSheet> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() { _userCtrl.dispose(); _passCtrl.dispose(); super.dispose(); }

  Future<void> _handleLogin() async {
    final username = _userCtrl.text.trim();
    final password = _passCtrl.text;
    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = 'Username dan kata sandi wajib diisi.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final result = await ApiService.loginPerangkat(username, password);
      if (!mounted) return;
      if (result['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        if (!mounted) return;
        for (final key in ['token', 'deviceToken', 'username', 'role', 'kodeUiw', 'kodeUp3', 'kodeUlp', 'ulp', 'bidang', 'tim', 'subTim', 'aksesMenu']) {
          await prefs.setString(key, (result[key] ?? '').toString());
        }
        if (!mounted) return;
        await LocalAuthService.saveAfterOnlineLogin(username: username, password: password, profile: result);
        if (!mounted) return;
        Navigator.pop(context);
        widget.onVerified(result);
      } else {
        setState(() => _error = (result['message'] ?? 'Login gagal.').toString());
      }
    } catch (_) {
      final offline = await LocalAuthService.verifyOffline(username: username, password: password);
      if (!mounted) return;
      if (offline != null) {
        final prefs = await SharedPreferences.getInstance();
        if (!mounted) return;
        for (final entry in offline.entries) {
          if (entry.key != 'success') await prefs.setString(entry.key, entry.value.toString());
        }
        if (!mounted) return;
        Navigator.pop(context);
        widget.onVerified(offline);
      } else {
        setState(() => _error = 'Tidak dapat terhubung ke API dan akun ini belum tersimpan untuk mode offline.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(30, 12, 30, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 44, height: 5, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: AppColors.neutral300, borderRadius: BorderRadius.circular(100)))),
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
                  decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF7FCFF), Colors.white]), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.navy100), boxShadow: [BoxShadow(color: AppColors.navy700.withValues(alpha: .08), blurRadius: 18, offset: const Offset(0, 6))]),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Row(children: [Container(width: 38, height: 38, decoration: BoxDecoration(color: AppColors.navy700, borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.lock_open_rounded, color: Colors.white, size: 20)), const SizedBox(width: 10), const Text('Masuk ke akun', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.neutral900))]),
                      IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => Navigator.pop(context)),
                    ]),
                    const SizedBox(height: 8),
                    const Padding(padding: EdgeInsets.only(left: 48), child: Text('Masukkan Akun yang Terdaftar (Format Akun <Kode ULP>.<Tim>)', style: TextStyle(fontSize: 13, height: 1.35, color: AppColors.neutral500))),
                    const SizedBox(height: 20),
                    if (_error != null) ...[Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.red100, borderRadius: BorderRadius.circular(12)), child: Row(children: [const Icon(Icons.error_outline, color: AppColors.red600, size: 17), const SizedBox(width: 9), Expanded(child: Text(_error!, style: const TextStyle(fontSize: 12, color: AppColors.red600)))])), const SizedBox(height: 16)],
                    const Text('Username', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.navy900)),
                    const SizedBox(height: 7),
                    _field(_userCtrl, 'Masukkan username', Icons.person_outline),
                    const SizedBox(height: 16),
                    const Text('Kata sandi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.navy900)),
                    const SizedBox(height: 7),
                    _field(_passCtrl, 'Masukkan kata sandi', Icons.lock_outline, obscure: _obscure, suffix: IconButton(icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18), onPressed: () => setState(() => _obscure = !_obscure))),
                    const SizedBox(height: 20),
                    SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _loading ? null : _handleLogin, style: ElevatedButton.styleFrom(backgroundColor: _loading ? AppColors.neutral300 : AppColors.amber600, foregroundColor: AppColors.navy950, disabledForegroundColor: AppColors.navy700, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0), child: _loading ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [SizedBox(width: 19, height: 19, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.navy700)), const SizedBox(width: 10), Text('Verifikasi Akun', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800))]) : const Text('Masuk', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)))),
                    const SizedBox(height: 14),
                    const Center(child: Text('Data kamu terenkripsi dan hanya dapat diakses oleh tim berwenang.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: AppColors.neutral500))),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String hint, IconData icon, {bool obscure = false, Widget? suffix}) => Container(
        height: 48,
        decoration: BoxDecoration(color: const Color(0xFFF1F7FC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFD7E6F2), width: 1.4)),
        child: TextField(controller: controller, obscureText: obscure, textAlignVertical: TextAlignVertical.center, decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: AppColors.neutral500, fontSize: 15), prefixIcon: Icon(icon, size: 18, color: AppColors.neutral500), suffixIcon: suffix, border: InputBorder.none, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14))),
      );
}

class _SafetyWelcomeDialog extends StatefulWidget {
  final Map<String, dynamic> sesi;
  const _SafetyWelcomeDialog({required this.sesi});

  @override
  State<_SafetyWelcomeDialog> createState() => _SafetyWelcomeDialogState();
}

class _SafetyWelcomeDialogState extends State<_SafetyWelcomeDialog> {
  Timer? _timer;
  int _remaining = 3;
  bool _canClose = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remaining <= 1) {
        timer.cancel();
        setState(() { _remaining = 0; _canClose = true; });
      } else {
        setState(() => _remaining--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _closeAndContinue() {
    if (!_canClose) return;
    Navigator.of(context).pop();
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => DashboardScreen(sesi: widget.sesi)));
  }

  @override
  Widget build(BuildContext context) {
    final subTim = (widget.sesi['subTim'] ?? widget.sesi['tim'] ?? 'Petugas').toString();
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: AppColors.navy950.withValues(alpha: .25), blurRadius: 28, offset: const Offset(0, 14))]),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 78, height: 78, decoration: BoxDecoration(color: AppColors.safetyCream, shape: BoxShape.circle, border: Border.all(color: AppColors.safetyOrange, width: 2)), child: const Icon(Icons.health_and_safety_rounded, size: 46, color: AppColors.safetyOrange)),
            const SizedBox(height: 18),
            const Text('Selamat Bekerja', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: AppColors.navy950)),
            const SizedBox(height: 6),
            const Text('Safety First', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.safetyOrange)),
            const SizedBox(height: 16),
            Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11), decoration: BoxDecoration(color: AppColors.navy100, borderRadius: BorderRadius.circular(13)), child: Text(subTim, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.navy700))),
            const SizedBox(height: 18),
            const Text('Semangaaaat Pagi!!!', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.navy700)),
            const SizedBox(height: 18),
            SizedBox(width: double.infinity, height: 46, child: ElevatedButton(onPressed: _canClose ? _closeAndContinue : null, style: ElevatedButton.styleFrom(backgroundColor: _canClose ? AppColors.navy700 : AppColors.neutral300, foregroundColor: Colors.white, disabledForegroundColor: AppColors.neutral500, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)), elevation: 0), child: Text(_canClose ? 'Mulai Bekerja' : 'Tunggu $_remaining detik...', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)))),
            const SizedBox(height: 10),
            Text(_canClose ? 'Klik tombol untuk menutup pesan ini.' : 'Pesan akan bisa ditutup setelah 3 detik.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: AppColors.neutral500)),
          ],
        ),
      ),
    );
  }
}
