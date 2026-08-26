import 'package:flutter_test/flutter_test.dart';
import 'package:simandist_mobile/main.dart';

void main() {
  testWidgets('Menampilkan halaman login SiManDist', (tester) async {
    await tester.pumpWidget(const SiManDistApp());

    expect(find.text('SiManDist'), findsOneWidget);
    expect(find.text('PLN UID BABEL'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });
}
