import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';

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
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

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
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(width: 132, height: 132, child: SvgPicture.asset('assets/icons/logo_app.svg')),
                  const SizedBox(height: 20),
                  const Text.rich(TextSpan(children: [
                    TextSpan(text: 'SiMan', style: TextStyle(color: AppColors.navy900)),
                    TextSpan(text: 'Dist', style: TextStyle(color: AppColors.amber600)),
                  ]), style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800)),
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
                      onPressed: () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => const _LoginSheet()),
                      icon: const Icon(Icons.login, size: 18),
                      label: const Text('Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                    ),
                  ),
                ]),
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
    width: 42, height: 42,
    decoration: BoxDecoration(color: AppColors.plnYellow, borderRadius: BorderRadius.circular(10)),
    child: const Icon(Icons.bolt, color: AppColors.plnRed, size: 28),
  );
}

class _LoginSheet extends StatefulWidget {
  const _LoginSheet();
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
    if (_userCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _error = 'Username dan kata sandi wajib diisi.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final result = await ApiService.login(_userCtrl.text.trim(), _passCtrl.text);
      if (!mounted) return;
      if (result['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        for (final key in ['token','username','role','kodeUiw','kodeUp3','kodeUlp','ulp','bidang','tim','subTim','aksesMenu']) {
          await prefs.setString(key, (result[key] ?? '').toString());
        }
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Selamat datang, ${result['username']}')));
      } else {
        setState(() => _error = (result['message'] ?? 'Login gagal.').toString());
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: AppColors.neutral300, borderRadius: BorderRadius.circular(100)))),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Masuk ke akun', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.neutral900)),
            IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => Navigator.pop(context)),
          ]),
          const Text('Gunakan akun yang terdaftar di PLN UID Babel.', style: TextStyle(fontSize: 13, color: AppColors.neutral500)),
          const SizedBox(height: 20),
          if (_error != null) ...[
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.red100, borderRadius: BorderRadius.circular(11)), child: Row(children: [const Icon(Icons.error_outline, color: AppColors.red600, size: 16), const SizedBox(width: 9), Expanded(child: Text(_error!, style: const TextStyle(fontSize: 12, color: AppColors.red600)))])),
            const SizedBox(height: 16),
          ],
          const Text('Username', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          _field(_userCtrl, 'Masukkan username', Icons.person_outline),
          const SizedBox(height: 16),
          const Text('Kata sandi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          _field(_passCtrl, 'Masukkan kata sandi', Icons.lock_outline, obscure: _obscure, suffix: IconButton(icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 17), onPressed: () => setState(() => _obscure = !_obscure))),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, height: 48, child: ElevatedButton(
            onPressed: _loading ? null : _handleLogin,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.amber600, foregroundColor: AppColors.navy950, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
            child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4)) : const Text('Masuk', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          )),
        ])),
      ),
    );
  }

  Widget _field(TextEditingController controller, String hint, IconData icon, {bool obscure = false, Widget? suffix}) => Container(
    height: 44,
    decoration: BoxDecoration(color: AppColors.neutral100, borderRadius: BorderRadius.circular(11), border: Border.all(color: AppColors.neutral200, width: 1.5)),
    child: TextField(controller: controller, obscureText: obscure, decoration: InputDecoration(hintText: hint, prefixIcon: Icon(icon, size: 17), suffixIcon: suffix, border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 12))),
  );
}
