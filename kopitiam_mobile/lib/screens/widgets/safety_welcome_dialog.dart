import 'dart:async';

import 'package:flutter/material.dart';

import '../dashboard_screen.dart';
import '../login_screen.dart';

class SafetyWelcomeDialog extends StatefulWidget {
  final Map<String, dynamic> session;
  const SafetyWelcomeDialog({super.key, required this.session});
  @override
  State<SafetyWelcomeDialog> createState() => _SafetyWelcomeDialogState();
}

class _SafetyWelcomeDialogState extends State<SafetyWelcomeDialog> {
  Timer? _timer;
  int _remaining = 3;
  bool _canClose = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remaining <= 1) { timer.cancel(); setState(() { _remaining = 0; _canClose = true; }); }
      else { setState(() => _remaining--); }
    });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  void _closeAndContinue() {
    if (!_canClose) return;
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.pushReplacement(MaterialPageRoute<void>(builder: (_) => DashboardScreen(sesi: widget.session)));
  }

  @override
  Widget build(BuildContext context) {
    final subTeam = (widget.session['subTim'] ?? widget.session['tim'] ?? 'Petugas').toString();
    return Dialog(
      backgroundColor: Colors.transparent, insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: AppColors.navy950.withValues(alpha: .25), blurRadius: 28, offset: const Offset(0, 14))]),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 78, height: 78, decoration: BoxDecoration(color: AppColors.safetyCream, shape: BoxShape.circle, border: Border.all(color: AppColors.safetyOrange, width: 2)), child: const Icon(Icons.health_and_safety_rounded, size: 46, color: AppColors.safetyOrange)),
          const SizedBox(height: 18),
          const Text('Selamat Bekerja', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: AppColors.navy950)),
          const SizedBox(height: 6),
          const Text('Safety First', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.safetyOrange)),
          const SizedBox(height: 16),
          Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11), decoration: BoxDecoration(color: AppColors.navy100, borderRadius: BorderRadius.circular(13)), child: Text(subTeam, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.navy700))),
          const SizedBox(height: 18),
          const Text('Semangaaaat Pagi!!!', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.navy700)),
          const SizedBox(height: 18),
          SizedBox(width: double.infinity, height: 46, child: ElevatedButton(
            onPressed: _canClose ? _closeAndContinue : null,
            style: ElevatedButton.styleFrom(backgroundColor: _canClose ? AppColors.navy700 : AppColors.neutral300, foregroundColor: Colors.white, disabledForegroundColor: AppColors.neutral500, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)), elevation: 0),
            child: Text(_canClose ? 'Mulai Bekerja' : 'Tunggu $_remaining detik...', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          )),
          const SizedBox(height: 10),
          Text(_canClose ? 'Klik tombol untuk menutup pesan ini.' : 'Pesan akan bisa ditutup setelah 3 detik.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: AppColors.neutral500)),
        ]),
      ),
    );
  }
}
