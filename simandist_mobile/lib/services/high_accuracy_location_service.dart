import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// Hasil pengambilan titik dengan metadata akurasi.
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

/// Mengambil koordinat perangkat dengan strategi multi-sampling.
///
/// Alur: satu pembacaan awal, lalu hingga 30 sampel dari position stream.
/// Sampel dengan akurasi terkecil dipakai, dan proses langsung dihentikan
/// (lock) begitu ada sampel dengan akurasi di bawah 5 meter.
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
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
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
      onSample?.call(samples, best!.accuracy);
    }

    try {
      final initial = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: Duration(seconds: 12),
        ),
      );
      consider(initial);
    } catch (_) {
      // Pembacaan pertama boleh gagal; stream di bawah tetap dicoba.
    }

    if (best != null && best!.accuracy <= lockAccuracy) {
      return _toFix(best!, samples, true);
    }

    final completer = Completer<void>();
    StreamSubscription<Position>? subscription;
    Timer? deadline;

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

    await completer.future;
    await subscription.cancel();
    deadline.cancel();

    final result = best;
    if (result == null) {
      throw StateError('Koordinat tidak terbaca. Coba di area terbuka.');
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

  /// Jarak antar dua koordinat dalam kilometer.
  static double distanceKm(LocationFix start, LocationFix end) {
    final meters = Geolocator.distanceBetween(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );
    return meters / 1000;
  }
}
