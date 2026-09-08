import 'package:flutter/material.dart';

import '../services/role_provider.dart';

class C4aRouteGuard extends StatelessWidget {
  final Map<String, dynamic> sesi;
  final Widget child;

  const C4aRouteGuard({super.key, required this.sesi, required this.child});

  @override
  Widget build(BuildContext context) =>
      RoleProvider.hasC4aAccess(sesi) ? child : const C4aAccessDeniedScreen();
}

class C4aAccessDeniedScreen extends StatelessWidget {
  const C4aAccessDeniedScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Temuan C4A')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 52, color: Colors.grey),
            const SizedBox(height: 14),
            const Text(
              'Akses C4A tidak tersedia untuk role ini.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Gunakan akun dengan role Super User, Admin, atau Pegawai PLN.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            if (Navigator.of(context).canPop())
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Kembali'),
              ),
          ],
        ),
      ),
    ),
  );
}
