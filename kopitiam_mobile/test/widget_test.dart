import 'package:flutter_test/flutter_test.dart';
import 'package:kopitiam_mobile/main.dart';

void main() {
  testWidgets('aplikasi Kopitiam dapat dibangun', (tester) async {
    await tester.pumpWidget(const SiManDistApp());
    await tester.pump();

    expect(find.text('Login'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
