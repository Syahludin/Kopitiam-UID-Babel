import 'dart:async';

import 'package:geolocator/geolocator.dart';

enum MockLocationCheck { trusted, mocked, unavailable }

class MockLocationGuardService {
  static Future<MockLocationCheck> check({
    bool requestPermission = true,
  }) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return MockLocationCheck.unavailable;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && requestPermission) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return MockLocationCheck.unavailable;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return position.isMocked
          ? MockLocationCheck.mocked
          : MockLocationCheck.trusted;
    } on TimeoutException {
      return MockLocationCheck.unavailable;
    } catch (_) {
      return MockLocationCheck.unavailable;
    }
  }
}
