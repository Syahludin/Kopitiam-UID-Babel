import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopitiam_mobile/screens/c4a_route_guard.dart';
import 'package:kopitiam_mobile/services/role_provider.dart';

void main() {
  test('C4A hanya menerima tiga role pusat yang diizinkan', () {
    for (final role in ['Super User', 'Admin', 'Pegawai PLN']) {
      expect(RoleProvider.canAccessC4aRole(role), isTrue, reason: role);
    }
    for (final role in ['User', 'Vendor', 'Pegawai', '']) {
      expect(RoleProvider.canAccessC4aRole(role), isFalse, reason: role);
    }
  });

  test('provider membawa identitas sesi dan role online', () {
    final provider = RoleProvider.fromSession({
      'kodeUiw': '16',
      'kodeUp3': '161',
      'kodeUlp': '16140',
      'ulp': 'ULP Koba',
      'username': 'pegawai',
      'role': 'Admin',
      'roleVerifiedOnline': true,
    });

    expect(provider.profile.kodeUiw, '16');
    expect(provider.profile.kodeUp3, '161');
    expect(provider.profile.kodeUlp, '16140');
    expect(provider.profile.ulp, 'ULP Koba');
    expect(provider.profile.username, 'pegawai');
    expect(provider.canAccessC4a, isTrue);
  });

  test('role yang di-cache offline berlaku sampai waktu kedaluwarsa', () {
    final valid = RoleProvider.markOffline({
      'role': 'Pegawai PLN',
    }, DateTime.now().toUtc());
    expect(RoleProvider.hasC4aAccess(valid), isTrue);

    final expired = RoleProvider.markOffline({
      'role': 'Pegawai PLN',
    }, DateTime.now().toUtc().subtract(const Duration(days: 1)));
    expect(RoleProvider.hasC4aAccess(expired), isFalse);
  });

  test('role offline User/vendor tidak mendapat akses meskipun ter-cache', () {
    final session = RoleProvider.markOffline({
      'role': 'Vendor',
    }, DateTime.now().toUtc());
    expect(RoleProvider.hasC4aAccess(session), isFalse);
  });

  testWidgets('guard menolak tautan langsung untuk role User/vendor', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: C4aRouteGuard(
          sesi: const {'role': 'User'},
          child: const Text('C4A rahasia'),
        ),
      ),
    );

    expect(find.text('C4A rahasia'), findsNothing);
    expect(
      find.text('Akses C4A tidak tersedia untuk role ini.'),
      findsOneWidget,
    );
  });
}
