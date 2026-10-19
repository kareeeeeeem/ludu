import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ludo_club/api.dart';
import 'package:ludo_club/wallet_screen.dart';

class WalletApi extends Api {
  WalletApi({this.configured = true}) {
    user = {'id': 'test-player', 'availableMinor': 10000, 'reservedMinor': 0};
  }
  final bool configured;
  String receivingPhone = 'LOCAL_DEMO_NO_REAL_TRANSFER';
  final List<Map<String, dynamic>> requests = [];
  @override
  Future<dynamic> call(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    if (method == 'POST') {
      requests.add({'path': path, ...?body});
      return {'status': 'PENDING'};
    }
    if (path == '/wallet/config') {
      return {
        'depositAvailable': configured,
        'receivingPhone': configured ? receivingPhone : null,
        'localDemo': configured && receivingPhone.startsWith('LOCAL_DEMO_'),
      };
    }
    if (path.startsWith('/wallet/')) return [];
    return {};
  }

  @override
  Future<void> refresh() async {}
}

void main() {
  FlutterSecureStorage.setMockInitialValues({});
  test(
    'EGP parser uses exact integer piastres and rejects malformed amounts',
    () {
      expect(parseEgp('25.05'), 2505);
      expect(parseEgp('0.01'), 1);
      expect(parseEgp('1.999'), isNull);
      expect(parseEgp('-1'), isNull);
      expect(parseEgp('1e9'), isNull);
      expect(parseEgp('0'), isNull);
      expect(egp(2505), '25.05 EGP');
    },
  );

  testWidgets(
    'wallet shows available and reserved; missing receiving config disables deposit',
    (tester) async {
      final api = WalletApi(configured: false);
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: WalletScreen(api: api))),
      );
      await tester.pumpAndSettle();
      expect(find.text('100.00 EGP'), findsOneWidget);
      expect(find.text('0.00 EGP reserved'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(
                FilledButton,
                'Deposit request · Vodafone Cash',
              ),
            )
            .onPressed,
        isNull,
      );
      api.dispose();
    },
  );

  testWidgets(
    'deposit request stays pending; withdrawal request sends minor units',
    (tester) async {
      final api = WalletApi();
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: WalletScreen(api: api))),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deposit request · Vodafone Cash'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Do not send any real money'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Amount (EGP)'),
        '25.50',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Sender phone'),
        '01000000000',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Transfer reference'),
        'LOCAL-TEST-1',
      );
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(api.requests.single['amountMinor'], 2550);
      expect(api.requests.single['path'], '/wallet/deposits');
      expect(
        find.textContaining('balance has not been credited'),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.text('Withdrawal request · Vodafone Cash'),
      );
      await tester.tap(find.text('Withdrawal request · Vodafone Cash'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Amount (EGP)'),
        '10.01',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Vodafone Cash phone'),
        '01000000000',
      );
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(api.requests.last['amountMinor'], 1001);
      expect(api.requests.last['path'], '/wallet/withdrawals');
      api.dispose();
    },
  );

  testWidgets('opening Deposit refetches the latest backend receiving number', (
    tester,
  ) async {
    final api = WalletApi()..receivingPhone = '01004632660';
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: WalletScreen(api: api))),
    );
    await tester.pumpAndSettle();
    api.receivingPhone = '01000000000';
    await tester.tap(find.text('Deposit request · Vodafone Cash'));
    await tester.pumpAndSettle();
    expect(find.textContaining('01000000000'), findsOneWidget);
    expect(find.textContaining('01004632660'), findsNothing);
    api.dispose();
  });
}
