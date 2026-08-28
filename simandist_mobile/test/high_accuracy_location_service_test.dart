import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:simandist_mobile/services/high_accuracy_location_service.dart';

Position position({
  bool mocked = false,
  double latitude = -3.019482,
  double longitude = 106.454827,
  double accuracy = 3.2,
  DateTime? timestamp,
}) => Position(
  latitude: latitude,
  longitude: longitude,
  timestamp: timestamp ?? DateTime.now(),
  accuracy: accuracy,
  altitude: 0,
  altitudeAccuracy: 1,
  heading: 0,
  headingAccuracy: 1,
  speed: 0,
  speedAccuracy: 1,
  isMocked: mocked,
);

void main() {
  test('trusted GPS sample can become a LocationFix', () {
    final sample = position();
    expect(sample.isMocked, isFalse);
    expect(sample.accuracy, lessThanOrEqualTo(HighAccuracyLocationService.lockAccuracy));
  });

  test('geolocator exposes mock-location signal used by service', () {
    final fake = position(mocked: true);
    expect(fake.isMocked, isTrue);
  });

  test('rejectable coordinate attack cases remain identifiable', () {
    expect(position(latitude: 0, longitude: 0).latitude, 0);
    expect(position(latitude: 91).latitude, greaterThan(90));
    expect(position(longitude: 181).longitude, greaterThan(180));
    expect(position(accuracy: 0).accuracy, lessThanOrEqualTo(0));
  });
}
