import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopitiam_mobile/screens/startup_screen.dart';

void main() {
  testWidgets('cincin loader berputar sementara petir tetap di tengah', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: KopitiamLoading(size: 72))),
      ),
    );

    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.byType(Transform), findsWidgets);
    final first = tester
        .widgetList<Transform>(find.byType(Transform))
        .map((widget) => widget.transform.storage.toList())
        .toList();

    await tester.pump(const Duration(milliseconds: 225));
    final second = tester
        .widgetList<Transform>(find.byType(Transform))
        .map((widget) => widget.transform.storage.toList())
        .toList();
    expect(second, isNot(first));
  });

  test('aset petir statis tersedia dan loader tidak bergantung SMIL', () {
    expect(File('assets/icons/loading_bolt.svg').existsSync(), true);
    final source = File('lib/screens/startup_screen.dart').readAsStringSync();
    expect(source, contains('AnimationController'));
    expect(source, contains('Transform.rotate'));
    expect(source, contains('_LoadingRingPainter'));
  });
}
