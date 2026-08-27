import 'package:flutter_test/flutter_test.dart';
import 'package:simandist_mobile/main.dart';

void main() {
  testWidgets('aplikasi SiManDist dapat dibangun', (tester) async {
    await tester.pumpWidget(const SiManDistApp());
    await tester.pump();

    expect(find.text('Login'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
