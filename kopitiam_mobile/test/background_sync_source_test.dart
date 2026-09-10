import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android manifest declares a dataSync foreground service', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(manifest, contains('android.permission.FOREGROUND_SERVICE'));
    expect(manifest, contains('android.permission.FOREGROUND_SERVICE_DATA_SYNC'));
    expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
    expect(manifest, contains('android:foregroundServiceType="dataSync"'));
    expect(manifest, contains('android:stopWithTask="true"'));
  });

  test('native service is non-sticky and stops when task is removed', () {
    final service = File(
      'android/app/src/main/kotlin/id/co/uidbabel/kopitiam/'
      'DataSyncForegroundService.kt',
    ).readAsStringSync();
    expect(service, contains('FOREGROUND_SERVICE_TYPE_DATA_SYNC'));
    expect(service, contains('START_NOT_STICKY'));
    expect(service, contains('onTaskRemoved'));
    expect(service, contains('setOngoing(true)'));
  });

  test('tracked API operations start and stop the foreground service', () {
    final activity = File('lib/services/api_activity.dart').readAsStringSync();
    expect(activity, contains('BackgroundSyncService.start(label)'));
    expect(activity, contains('BackgroundSyncService.stop()'));
    expect(activity, contains("action.startsWith('syncWo')"));
    expect(activity, contains("action == 'getMasterData'"));
  });
}
