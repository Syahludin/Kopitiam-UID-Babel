import 'dart:async';
import 'dart:math' as math;

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
  static const double stabilityRadius = 8;
  static const int minimumStableSamples = 4;
  static const int maxSamples = 30;
  static const Duration maxDuration = Duration(seconds: 45);
  static const Duration maxPositionAge = Duration(seconds: 30);

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

  static void _assertTrusted(Position position) {
    if (position.isMocked) {
      throw StateError(
        'Lokasi tiruan terdeteksi. Nonaktifkan Fake GPS atau aplikasi '
        'pengubah lokasi, lalu ambil koordinat ulang.',
      );
    }
    if (!position.latitude.isFinite ||
        !position.longitude.isFinite ||
        !position.accuracy.isFinite ||
        position.latitude < -90 ||
        position.latitude > 90 ||
        position.longitude < -180 ||
        position.longitude > 180 ||
        (position.latitude == 0 && position.longitude == 0) ||
        position.accuracy <= 0) {
      throw StateError('Data lokasi perangkat tidak valid.');
    }
    final now = DateTime.now();
    final age = now.difference(position.timestamp);
    if (age > maxPositionAge || age < const Duration(minutes: -1)) {
      throw StateError(
        'Data GPS sudah kedaluwarsa atau waktu perangkat tidak valid.',
      );
    }
  }

  /// Menguatkan titik GPS dari beberapa sampel, bukan mempercayai satu bacaan.
  ///
  /// Sampel yang jauh dari titik terbaik dibuang sebagai outlier. Sampel yang
  /// tersisa dirata-ratakan dengan bobot 1/accuracy², sehingga bacaan dengan
  /// akurasi lebih baik memberi pengaruh lebih besar. Titik baru dianggap
  /// terkunci hanya jika sedikitnya empat sampel konsisten dan estimasi
  /// akurasinya mencapai lima meter atau lebih baik.
  static LocationFix? strengthen(List<Position> positions) {
    if (positions.isEmpty) return null;

    final best = positions.reduce(
      (left, right) => left.accuracy <= right.accuracy ? left : right,
    );
    final allowedDistance = math.max(
      stabilityRadius,
      best.accuracy * 2,
    );
    final allowedAccuracy = math.max(20.0, best.accuracy * 3);
    final candidates = positions.where((position) {
      final distance = Geolocator.distanceBetween(
        best.latitude,
        best.longitude,
        position.latitude,
        position.longitude,
      );
      return position.accuracy <= allowedAccuracy &&
          distance <= allowedDistance;
    }).toList(growable: false);

    if (candidates.isEmpty) return null;

    var totalWeight = 0.0;
    var weightedLatitude = 0.0;
    var weightedLongitude = 0.0;
    var weightedAccuracy = 0.0;
    for (final position in candidates) {
      final accuracy = math.max(position.accuracy, 1.0);
      final weight = 1 / (accuracy * accuracy);
      totalWeight += weight;
      weightedLatitude += position.latitude * weight;
      weightedLongitude += position.longitude * weight;
      weightedAccuracy += position.accuracy * weight;
    }

    final latitude = weightedLatitude / totalWeight;
    final longitude = weightedLongitude / totalWeight;
    var spread = 0.0;
    for (final position in candidates) {
      spread = math.max(
        spread,
        Geolocator.distanceBetween(
          latitude,
          longitude,
          position.latitude,
          position.longitude,
        ),
      );
    }

    final estimatedAccuracy = math.max(
      weightedAccuracy / totalWeight,
      spread,
    );
    final locked = candidates.length >= minimumStableSamples &&
        best.accuracy <= lockAccuracy &&
        estimatedAccuracy <= lockAccuracy &&
        spread <= stabilityRadius;

    return LocationFix(
      latitude: latitude,
      longitude: longitude,
      accuracy: estimatedAccuracy,
      capturedAt: DateTime.now(),
      samples: candidates.length,
      locked: locked,
    );
  }

  static Future<LocationFix> acquire({
    void Function(int sample, double bestAccuracy)? onSample,
  }) async {
    await _ensureReady();

    final positions = <Position>[];
    var samples = 0;
    Object? securityError;

    bool consider(Position position) {
      try {
        _assertTrusted(position);
      } catch (error) {
        securityError = error;
        rethrow;
      }
      positions.add(position);
      samples++;
      final strengthened = strengthen(positions);
      final displayedAccuracy = strengthened?.accuracy ?? position.accuracy;
      onSample?.call(samples, displayedAccuracy);
      return strengthened?.locked ?? false;
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
    } on StateError {
      rethrow;
    } catch (_) {
      // Provider awal bisa belum siap; stream berikutnya tetap dicoba.
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
        try {
          final locked = consider(position);
          if (locked || samples >= maxSamples) finish();
        } catch (_) {
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

    if (securityError != null) throw securityError!;
    final result = strengthen(positions);
    if (result == null) {
      throw StateError('Koordinat tidak terbaca. Coba lagi di area terbuka.');
    }
    return result;
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
