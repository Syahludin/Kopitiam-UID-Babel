import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app startup guard forces logout and blocks login on mocked location', () {
    final main = File('lib/main.dart').readAsStringSync();
    final service = File(
      'lib/services/mock_location_guard_service.dart',
    ).readAsStringSync();

    expect(service, contains('position.isMocked'));
    expect(main, contains('MockLocationCheck.mocked'));
    expect(main, contains('_forceLogoutForMockLocation'));
    expect(main, contains('ApiService.logoutPerangkat'));
    expect(main, contains('pushAndRemoveUntil'));
    expect(main, contains('AbsorbPointer'));
    expect(main, contains('Lokasi tiruan terdeteksi'));
    expect(main, contains('Periksa ulang'));
  });
}
