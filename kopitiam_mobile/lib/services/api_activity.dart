import 'package:flutter/foundation.dart';

class ApiActivityState {
  final String action;
  final String label;
  const ApiActivityState(this.action, this.label);
}

abstract final class ApiActivity {
  static final ValueNotifier<ApiActivityState?> current = ValueNotifier(null);
  static int _active = 0;

  static bool supports(String action) =>
      action.startsWith('getWo') ||
      action.startsWith('syncWo') ||
      action == 'syncAllWo' ||
      action == 'getMasterData' ||
      action == 'getMasterGardu';

  static String labelFor(String action) {
    if (action == 'getMasterData' || action == 'getMasterGardu') {
      return 'Mengunduh master data';
    }
    if (action.startsWith('sync')) return 'Menyinkronkan Work Order';
    return 'Mengunduh Work Order';
  }

  static Future<T> track<T>(String action, Future<T> Function() request) async {
    if (!supports(action)) return request();
    _active++;
    current.value = ApiActivityState(action, labelFor(action));
    await Future<void>.delayed(Duration.zero);
    try {
      return await request();
    } finally {
      _active--;
      if (_active <= 0) {
        _active = 0;
        current.value = null;
      }
    }
  }
}
