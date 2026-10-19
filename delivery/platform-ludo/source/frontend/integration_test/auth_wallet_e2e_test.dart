import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ludo_club/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('anonymous entry restores the same identity after app restart', (
    tester,
  ) async {
    const storage = FlutterSecureStorage();
    await storage.deleteAll();

    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.text('LUDO / CLUB'), findsOneWidget);
    expect(find.text('Welcome back'), findsNothing);
    final greeting =
        tester.widget<Text>(find.textContaining('Hi, Guest_').first).data;
    final savedToken = await storage.read(key: 'token');
    expect(savedToken, isNotNull);

    await tester.tap(find.text('Wallet').last);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('Your wallet'), findsOneWidget);
    expect(find.textContaining('Available'), findsWidgets);
    expect(find.text('Deposit request · Vodafone Cash'), findsOneWidget);
    expect(find.text('Withdrawal request · Vodafone Cash'), findsOneWidget);

    await tester.tap(find.text('Deposit request · Vodafone Cash'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Do not send any real money'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Amount (EGP)'),
      '25.00',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Sender phone'),
      '01000000000',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Transfer reference'),
      'LOCAL-${DateTime.now().microsecondsSinceEpoch}',
    );
    await tester.tap(find.text('Submit'));
    for (
      var i = 0;
      i < 30 && find.text('25.00 EGP · PENDING').evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.text('25.00 EGP · PENDING'), findsOneWidget);
    expect(find.text('0.00 EGP'), findsOneWidget);

    await tester.ensureVisible(find.text('Withdrawal request · Vodafone Cash'));
    await tester.tap(find.text('Withdrawal request · Vodafone Cash'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Amount (EGP)'), '5');
    await tester.enterText(
      find.widgetWithText(TextField, 'Vodafone Cash phone'),
      '123',
    );
    await tester.tap(find.text('Submit'));
    await tester.pump();
    expect(find.text('No withdrawal requests'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.text(greeting!), findsOneWidget);
    expect(await storage.read(key: 'token'), savedToken);

    await tester.ensureVisible(find.text('Practice against bots'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Practice against bots'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2 players · A friendly duel'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('The game room'), findsOneWidget);
    await tester.ensureVisible(find.text('Roll the dice'));
    await tester.tap(find.text('Roll the dice'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await tester.ensureVisible(find.text('Forfeit game'));
    await tester.tap(find.text('Forfeit game'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('Practice complete · Stats unchanged'), findsOneWidget);
  });
}
