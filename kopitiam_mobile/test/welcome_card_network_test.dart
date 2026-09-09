import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopitiam_mobile/screens/widgets/welcome_card.dart';
import 'package:kopitiam_mobile/theme/kopitiam_theme.dart';

void main() {
  const session = {
    'username': '16130.Har',
    'subTim': 'Har',
    'ulp': 'ULP Toboali',
  };

  testWidgets('status Online memakai titik hijau', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KopitiamTheme.light,
        home: Scaffold(
          body: WelcomeCard(
            sesi: session,
            networkProbe: () async => true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ONLINE'), findsOneWidget);
    expect(find.text('Terhubung ke server'), findsOneWidget);
    final dot = tester.widget<Container>(
      find.byKey(const ValueKey('network-status-dot')),
    );
    final decoration = dot.decoration! as BoxDecoration;
    expect(decoration.color, KopitiamColors.success);
  });

  testWidgets('status Offline memakai titik merah', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KopitiamTheme.light,
        home: Scaffold(
          body: WelcomeCard(
            sesi: session,
            networkProbe: () async => false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('OFFLINE'), findsOneWidget);
    expect(find.text('Mode offline aktif'), findsOneWidget);
    final dot = tester.widget<Container>(
      find.byKey(const ValueKey('network-status-dot')),
    );
    final decoration = dot.decoration! as BoxDecoration;
    expect(decoration.color, KopitiamColors.danger);
  });
}
