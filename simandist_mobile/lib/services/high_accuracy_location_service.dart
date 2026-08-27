import 'dart:async';

import 'package:geolocator/geolocator.dart';

class LocationFix {
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime capturedAt;
  final int samples;
  final bool locked;

  const LocationFix({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.capturedAt,
    required this.samples,
    required this.locked,
  });

  String get coordinate =>
      '${latitude.toStringAsFixed(7)},${longitude.toStringAsFixed(7)}';

  String get accuracyLabel => '${accuracy.toStringAsFixed(1)} m';
}

class HighAccuracyLocationService {
  static const double lockAccuracy = 5;
  static const int maxSamples = 30;
  static const Duration maxDuration = Duration(seconds: 45);

  static Future<void> _ensureReady() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('Layanan lokasi perangkat belum aktif.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw StateError(
        'Izin lokasi ditolak permanen. Aktifkan melalui pengaturan aplikasi.',
      );
    }
    if (permission == LocationPermission.denied) {
      throw StateError('Izin lokasi belum diberikan untuk aplikasi ini.');
    }
  }

  static Future<LocationFix> acquire({
    void Function(int sample, double bestAccuracy)? onSample,
  }) async {
    await _ensureReady();

    Position? best;
    var samples = 0;

    void consider(Position position) {
      samples++;
      if (best == null || position.accuracy < best!.accuracy) {
        best = position;
      }
      final currentBest = best;
      if (currentBest != null) {
        onSample?.call(samples, currentBest.accuracy);
      }
    }

    try {
      final initial = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: Duration(seconds: 12),
        ),
      );
      consider(initial);
    } on TimeoutException {
      // Stream berikutnya tetap mencoba pembacaan GPS.
    } catch (_) {
      // Provider awal bisa belum siap; stream berikutnya tetap dicoba.
    }

    final initialBest = best;
    if (initialBest != null && initialBest.accuracy <= lockAccuracy) {
      return _toFix(initialBest, samples, true);
    }

    final completer = Completer<void>();
    late final StreamSubscription<Position> subscription;
    late final Timer deadline;

    void finish() {
      if (!completer.isCompleted) completer.complete();
    }

    subscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
      ),
    ).listen(
      (position) {
        consider(position);
        if (position.accuracy <= lockAccuracy || samples >= maxSamples) {
          finish();
        }
      },
      onError: (_) => finish(),
      cancelOnError: false,
    );
    deadline = Timer(maxDuration, finish);

    try {
      await completer.future;
    } finally {
      deadline.cancel();
      await subscription.cancel();
    }

    final result = best;
    if (result == null) {
      throw StateError('Koordinat tidak terbaca. Coba lagi di area terbuka.');
    }
    return _toFix(result, samples, result.accuracy <= lockAccuracy);
  }

  static LocationFix _toFix(Position position, int samples, bool locked) {
    return LocationFix(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      capturedAt: DateTime.now(),
      samples: samples,
      locked: locked,
    );
  }

  static double distanceKm(LocationFix start, LocationFix end) {
    return Geolocator.distanceBetween(
          start.latitude,
          start.longitude,
          end.latitude,
          end.longitude,
        ) /
        1000;
  }
}
