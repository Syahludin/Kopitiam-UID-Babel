import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'widgets/login_sheet.dart';
import 'widgets/safety_welcome_dialog.dart';

class AppColors {
  static const navy950 = Color(0xFF071B30);
  static const navy900 = Color(0xFF0F172A);
  static const navy700 = Color(0xFF004D8C);
  static const navy100 = Color(0xFFD9F5FF);
  static const amber600 = Color(0xFFFFB800);
  static const neutral900 = Color(0xFF0F172A);
  static const neutral500 = Color(0xFF64748B);
  static const neutral300 = Color(0xFFCBD5E1);
  static const red600 = Color(0xFFDC2626);
  static const red100 = Color(0xFFFEE2E2);
  static const plnYellow = Color(0xFFFFDE00);
  static const plnRed = Color(0xFFE30613);
  static const safetyOrange = Color(0xFFF97316);
  static const safetyCream = Color(0xFFFFF7ED);
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  void _showSafetyWelcome(BuildContext context, Map<String, dynamic> session) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: AppColors.navy950.withValues(alpha: .72),
      builder: (_) => SafetyWelcomeDialog(session: session),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Stack(
            children: [
              const Positioned(top: 12, right: 20, child: _PlnBadge()),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgPicture.asset(
                        'assets/icons/logo_app.svg',
                        width: 132,
                        height: 132,
                      ),
                      const SizedBox(height: 18),
                      const Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Kopi',
                              style: TextStyle(color: AppColors.navy900),
                            ),
                            TextSpan(
                              text: 'tiam',
                              style: TextStyle(color: AppColors.amber600),
                            ),
                          ],
                        ),
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Kontrol Pemeliharaan dan Inspeksi Aset Mandiri',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.neutral500,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.navy100,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 13,
                              color: AppColors.amber600,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'PLN UID BABEL',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: .5,
                                color: AppColors.navy700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 36),
                      SizedBox(
                        width: 260,
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: () => showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            useSafeArea: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => LoginSheet(
                              onVerified: (session) =>
                                  _showSafetyWelcome(context, session),
                            ),
                          ),
                          icon: const Icon(Icons.login, size: 18),
                          label: const Text(
                            'Login',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.navy700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Positioned(
                bottom: 18,
                left: 16,
                right: 16,
                child: Text(
                  'Kopitiam © 2026 • PLN UID Babel',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.neutral500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _PlnBadge extends StatelessWidget {
  const _PlnBadge();

  @override
  Widget build(BuildContext context) => Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.plnYellow,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .15),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(Icons.bolt, color: AppColors.plnRed, size: 28),
      );
}
