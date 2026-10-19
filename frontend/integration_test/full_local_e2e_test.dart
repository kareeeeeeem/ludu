import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:ludo_club/api.dart';
import 'package:ludo_club/main.dart' as app;
import 'package:uuid/uuid.dart';

const adminEmail = String.fromEnvironment('E2E_ADMIN_EMAIL');
const adminPassword = String.fromEnvironment('E2E_ADMIN_PASSWORD');
const phone = '01000000000'; // Test fixture only; no transfer is sent.
const storage = FlutterSecureStorage();

Future<(int, dynamic)> call(
  String method,
  String path, {
  String? token,
  Map<String, dynamic>? body,
}) async {
  final request = http.Request(method, Uri.parse('${Api.base}/api$path'));
  request.headers['Content-Type'] = 'application/json';
  if (token != null) request.headers['Authorization'] = 'Bearer $token';
  if (body != null) request.body = jsonEncode(body);
  final response = await http.Response.fromStream(await request.send());
  return (response.statusCode, jsonDecode(response.body));
}

Future<Map<String, dynamic>> ok(
  String method,
  String path, {
  String? token,
  Map<String, dynamic>? body,
}) async {
  final (status, data) = await call(method, path, token: token, body: body);
  expect(status, inInclusiveRange(200, 201), reason: '$path: $data');
  return Map<String, dynamic>.from(data);
}

Future<Map<String, dynamic>> balance(String token) =>
    ok('GET', '/wallet/balance', token: token);

Future<void> restartAs(
  WidgetTester tester,
  String token,
  String? refreshToken,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await storage.write(key: 'token', value: token);
  if (refreshToken == null) {
    await storage.delete(key: 'refreshToken');
  } else {
    await storage.write(key: 'refreshToken', value: refreshToken);
  }
  app.main();
  await tester.pumpAndSettle(const Duration(seconds: 3));
  expect(find.text('LUDO / CLUB'), findsOneWidget);
}

Future<void> selectAdmin(WidgetTester tester, String section) async {
  await tester.tap(find.byType(DropdownButton<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(section.toUpperCase()).last);
  await tester.pumpAndSettle();
}

Future<void> adminAction(
  WidgetTester tester,
  String marker,
  String label, {
  String? payoutReference,
}) async {
  final markerFinder = find.textContaining(marker);
  await tester.ensureVisible(markerFinder);
  final card = find.ancestor(of: markerFinder, matching: find.byType(Card));
  await tester.tap(find.descendant(of: card, matching: find.text(label)));
  await tester.pumpAndSettle();
  if (payoutReference != null) {
    await tester.enterText(find.byType(TextField).last, payoutReference);
    await tester.tap(find.text('Confirm').last);
    await tester.pumpAndSettle();
  }
  await tester.enterText(
    find.byType(TextField).last,
    'Verified local E2E test only',
  );
  await tester.tap(find.text('Confirm').last);
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

Future<void> openWallet(WidgetTester tester) async {
  await tester.tap(find.text('Wallet').last);
  await tester.pumpAndSettle(const Duration(seconds: 2));
  expect(find.text('Your wallet'), findsOneWidget);
}

Future<void> submitWithdrawal(WidgetTester tester, String amount) async {
  await tester.ensureVisible(find.text('Withdrawal request · Vodafone Cash'));
  await tester.tap(find.text('Withdrawal request · Vodafone Cash'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.widgetWithText(TextField, 'Amount (EGP)'),
    amount,
  );
  await tester.enterText(
    find.widgetWithText(TextField, 'Vodafone Cash phone'),
    phone,
  );
  await tester.tap(find.text('Submit'));
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('complete local player UI, admin UI and paid match flow', (
    tester,
  ) async {
    expect(adminEmail, isNotEmpty);
    expect(adminPassword, isNotEmpty);
    final oldToken = await storage.read(key: 'token');
    final oldRefresh = await storage.read(key: 'refreshToken');
    await storage.deleteAll();
    try {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.text('LUDO / CLUB'), findsOneWidget);
      expect(find.text('Welcome back'), findsNothing);
      final aToken = (await storage.read(key: 'token'))!;
      final aRefresh = await storage.read(key: 'refreshToken');
      final a = await ok('GET', '/auth/me', token: aToken);
      expect((await balance(aToken))['availableMinor'], 0);
      await openWallet(tester);
      expect(find.text('No transactions yet'), findsOneWidget);

      // A submitted request is not money. Use an unmistakable test reference.
      final reference = 'UIE2E-${DateTime.now().microsecondsSinceEpoch}';
      await tester.tap(find.text('Deposit request · Vodafone Cash'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Do not send any real money'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Amount (EGP)'),
        '100.00',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Sender phone'),
        phone,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Transfer reference'),
        reference,
      );
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      // The list endpoint returns an array; inspect it without writing to DB.
      final (_, depositList) = await call(
        'GET',
        '/wallet/deposits',
        token: aToken,
      );
      final deposit = (depositList as List).cast<Map>().firstWhere(
        (row) => row['transferReference'] == reference,
      );
      expect(deposit['status'], 'PENDING');
      expect((await balance(aToken))['availableMinor'], 0);
      expect(find.text('100.00 EGP · PENDING'), findsOneWidget);

      // Actual admin sign-in screen and actual deposit approval control.
      await tester.tap(find.text('Profile').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Administrator sign in'));
      await tester.tap(find.text('Administrator sign in'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Admin email'),
        adminEmail,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Password'),
        adminPassword,
      );
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      final adminToken = (await storage.read(key: 'token'))!;
      expect((await ok('GET', '/auth/me', token: adminToken))['role'], 'admin');
      await tester.ensureVisible(find.text('Administration'));
      await tester.tap(find.text('Administration'));
      await tester.pumpAndSettle();
      await selectAdmin(tester, 'deposits');
      await adminAction(tester, reference, 'Approve verified transfer');
      expect((await balance(aToken))['availableMinor'], 10000);
      final duplicateDeposit = await call(
        'PUT',
        '/admin/deposits/${deposit['_id']}/approve',
        token: adminToken,
        body: {'reason': 'Duplicate approval test'},
      );
      expect(duplicateDeposit.$1, 200);
      expect((await balance(aToken))['availableMinor'], 10000);

      // A second legitimate guest client funds via audited admin adjustment.
      final b = await ok('POST', '/auth/guest');
      final bToken = b['token'] as String;
      final bId = (b['user'] as Map)['id'] as String;
      await ok(
        'PUT',
        '/admin/users/$bId/balance',
        token: adminToken,
        body: {
          'amountMinor': 10000,
          'reason': 'Controlled local E2E test funding',
          'requestId': const Uuid().v4(),
        },
      );
      expect((await balance(bToken))['availableMinor'], 10000);
      await restartAs(tester, aToken, aRefresh);
      await openWallet(tester);
      expect(find.text('100.00 EGP'), findsWidgets);
      expect(find.textContaining('DEPOSIT · 100.00 EGP'), findsOneWidget);

      // Create a paid private room in Flutter; B joins via normal authenticated API.
      await tester.tap(find.text('Play').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create a private room'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('25 EGP'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2 players · A friendly duel'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text('Your private table'), findsOneWidget);
      final active = await ok('GET', '/auth/me', token: aToken);
      final matchId = active['activeGame'] as String;
      final room = await ok('GET', '/games/$matchId', token: aToken);
      expect(room['stakeMinor'], 2500);
      expect((await balance(aToken))['availableMinor'], 7500);
      expect((await balance(aToken))['reservedMinor'], 2500);
      await ok(
        'POST',
        '/rooms/join',
        token: bToken,
        body: {'code': room['code']},
      );
      expect((await balance(bToken))['availableMinor'], 7500);
      expect((await balance(bToken))['reservedMinor'], 2500);
      await tester.tap(find.byTooltip('Sync game'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Start game'));
      await tester.tap(find.text('Start game'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text('The game room'), findsOneWidget);
      expect((await balance(aToken))['reservedMinor'], 0);
      expect((await balance(bToken))['reservedMinor'], 0);
      final started = await ok('GET', '/games/$matchId', token: bToken);
      expect(started['prizePoolMinor'], 5000);
      expect(started['status'], 'active');
      await restartAs(tester, aToken, aRefresh);
      expect(find.text('Return to your game'), findsOneWidget);
      await tester.tap(find.text('Return to your game'));
      await tester.pumpAndSettle();
      expect(find.text('The game room'), findsOneWidget);
      expect((await balance(aToken))['availableMinor'], 7500);
      expect((await balance(bToken))['availableMinor'], 7500);
      expect(
        (await call(
          'POST',
          '/games/$matchId/action',
          token: bToken,
          body: {'type': 'roll', 'revision': 0},
        )).$1,
        409,
      );
      expect(
        (await call(
          'POST',
          '/games/$matchId/action',
          token: aToken,
          body: {'type': 'roll', 'revision': 0, 'dice': 6},
        )).$1,
        400,
      );
      await tester.ensureVisible(find.text('Roll the dice'));
      await tester.tap(find.text('Roll the dice'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      final played = await ok('GET', '/games/$matchId', token: bToken);
      expect((played['state'] as Map)['revision'], greaterThan(0));
      // B legitimately forfeits. The server, not the client, picks A as winner.
      final ended = await ok(
        'POST',
        '/games/$matchId/action',
        token: bToken,
        body: {
          'type': 'forfeit',
          'revision': (played['state'] as Map)['revision'],
        },
      );
      expect(ended['status'], 'completed');
      expect((ended['state'] as Map)['winner'], a['id']);
      expect((await balance(aToken))['availableMinor'], 12500);
      expect((await balance(bToken))['availableMinor'], 7500);
      expect((await balance(aToken))['reservedMinor'], 0);
      expect((await balance(bToken))['reservedMinor'], 0);
      await tester.tap(find.byTooltip('Sync game'));
      await tester.pumpAndSettle();
      expect(find.textContaining('wins!'), findsOneWidget);

      // The completed game's public routes cannot cause another settlement.
      expect(
        (await call(
          'POST',
          '/games/$matchId/action',
          token: aToken,
          body: {
            'type': 'forfeit',
            'revision': (ended['state'] as Map)['revision'],
          },
        )).$1,
        409,
      );
      expect((await balance(aToken))['availableMinor'], 12500);
      final (_, txRaw) = await call(
        'GET',
        '/wallet/transactions',
        token: aToken,
      );
      final tx = (txRaw as List).cast<Map>();
      expect(
        tx
            .where((row) => row['type'] == 'PRIZE' && row['matchId'] == matchId)
            .length,
        1,
      );
      expect(
        tx
            .where(
              (row) =>
                  row['type'] == 'DEPOSIT' &&
                  row['depositRequestId'] == deposit['_id'],
            )
            .length,
        1,
      );

      // Restart in the middle of the financial session and use the player UI.
      await restartAs(tester, aToken, aRefresh);
      await openWallet(tester);
      expect(find.textContaining('PRIZE · 50.00 EGP'), findsOneWidget);
      await submitWithdrawal(tester, '20.00');
      final (_, wdRaw) = await call(
        'GET',
        '/wallet/withdrawals',
        token: aToken,
      );
      final paidRequest = (wdRaw as List).cast<Map>().first;
      expect(paidRequest['status'], 'PENDING');
      expect((await balance(aToken))['availableMinor'], 10500);
      expect((await balance(aToken))['reservedMinor'], 2000);

      // Reopen the real AdminScreen for payout confirmation, without sending money.
      await restartAs(tester, adminToken, null);
      await tester.tap(find.text('Profile').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Administration'));
      await tester.tap(find.text('Administration'));
      await tester.pumpAndSettle();
      await selectAdmin(tester, 'withdrawals');
      expect(find.textContaining('Send manually to $phone'), findsWidgets);
      expect(find.text('PENDING · 20.00 EGP'), findsOneWidget);
      final payoutReference =
          'LOCAL-PAID-${DateTime.now().microsecondsSinceEpoch}';
      await adminAction(
        tester,
        paidRequest['requestId'] as String,
        'Mark paid',
        payoutReference: payoutReference,
      );
      expect((await balance(aToken))['availableMinor'], 10500);
      expect((await balance(aToken))['reservedMinor'], 0);
      expect(
        (await call(
          'PUT',
          '/admin/withdrawals/${paidRequest['_id']}/paid',
          token: adminToken,
          body: {
            'reason': 'Duplicate paid test',
            'payoutReference': payoutReference,
          },
        )).$1,
        200,
      );
      expect((await balance(aToken))['availableMinor'], 10500);

      await restartAs(tester, aToken, aRefresh);
      await openWallet(tester);
      expect(find.text('20.00 EGP · PAID'), findsOneWidget);
      await submitWithdrawal(tester, '10.00');
      final (_, wd2Raw) = await call(
        'GET',
        '/wallet/withdrawals',
        token: aToken,
      );
      final rejected = (wd2Raw as List).cast<Map>().first;
      expect((await balance(aToken))['availableMinor'], 9500);
      expect((await balance(aToken))['reservedMinor'], 1000);
      await restartAs(tester, adminToken, null);
      await tester.tap(find.text('Profile').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Administration'));
      await tester.tap(find.text('Administration'));
      await tester.pumpAndSettle();
      await selectAdmin(tester, 'withdrawals');
      await adminAction(
        tester,
        rejected['requestId'] as String,
        'Reject and release',
      );
      expect((await balance(aToken))['availableMinor'], 10500);
      expect((await balance(aToken))['reservedMinor'], 0);
      expect(
        (await call(
          'PUT',
          '/admin/withdrawals/${rejected['_id']}/reject',
          token: adminToken,
          body: {'reason': 'Duplicate rejection test'},
        )).$1,
        200,
      );
      expect(
        (await call(
          'PUT',
          '/admin/withdrawals/${rejected['_id']}/paid',
          token: adminToken,
          body: {
            'reason': 'Invalid paid after reject',
            'payoutReference': 'LOCAL-NOT-PAID',
          },
        )).$1,
        409,
      );
      expect((await balance(aToken))['availableMinor'], 10500);

      // Real paid-room cancellation after reserve, plus an unfunded attempt.
      final cancelRoom = await ok(
        'POST',
        '/rooms/create',
        token: aToken,
        body: {'capacity': 2, 'stakeMinor': 2500},
      );
      expect((await balance(aToken))['availableMinor'], 8000);
      expect((await balance(aToken))['reservedMinor'], 2500);
      await ok('POST', '/games/${cancelRoom['id']}/leave', token: aToken);
      expect((await balance(aToken))['availableMinor'], 10500);
      expect((await balance(aToken))['reservedMinor'], 0);
      expect(
        (await call(
          'POST',
          '/games/${cancelRoom['id']}/leave',
          token: aToken,
        )).$1,
        409,
      );
      expect((await balance(aToken))['availableMinor'], 10500);
      final unfunded = await ok('POST', '/auth/guest');
      final unfundedToken = unfunded['token'] as String;
      expect(
        (await call(
          'POST',
          '/rooms/create',
          token: unfundedToken,
          body: {'capacity': 2, 'stakeMinor': 2500},
        )).$1,
        402,
      );
      expect((await balance(unfundedToken))['availableMinor'], 0);

      // Normal players cannot invoke any admin financial/game operation.
      for (final (method, path) in [
        ('PUT', '/admin/deposits/${deposit['_id']}/approve'),
        ('PUT', '/admin/withdrawals/${paidRequest['_id']}/paid'),
        ('PUT', '/admin/withdrawals/${rejected['_id']}/reject'),
        ('PUT', '/admin/users/${a['id']}/balance'),
        ('PUT', '/admin/games/$matchId/result'),
        ('GET', '/admin/transactions'),
      ]) {
        expect(
          (await call(
            method,
            path,
            token: aToken,
            body:
                method == 'PUT' ? {'reason': 'Unauthorized local test'} : null,
          )).$1,
          403,
        );
      }
      // 10000 + 10000 initial value, 2000 completed payout, match merely
      // transfers 2500 from B to A. Pending/rejected/cancelled actions add 0.
      expect((await balance(aToken))['availableMinor'], 10500);
      expect((await balance(bToken))['availableMinor'], 7500);
      expect(10500 + 7500, 10000 + 10000 - 2000);
      final (_, finalTxRaw) = await call(
        'GET',
        '/wallet/transactions',
        token: aToken,
      );
      final finalTx = (finalTxRaw as List).cast<Map>();
      for (final type in [
        'DEPOSIT',
        'STAKE_RESERVE',
        'STAKE_CAPTURE',
        'PRIZE',
        'WITHDRAWAL_RESERVE',
        'WITHDRAWAL_PAID',
        'WITHDRAWAL_RELEASE',
      ]) {
        expect(finalTx.any((row) => row['type'] == type), isTrue, reason: type);
      }
      expect(
        finalTx.where((row) => row['type'] == 'WITHDRAWAL_PAID').length,
        1,
      );
      expect(
        finalTx.where((row) => row['type'] == 'WITHDRAWAL_RELEASE').length,
        1,
      );
      debugPrint(
        'LOCAL_E2E A: 0 -> deposit 10000 -> stake -2500 + prize 5000 -> paid -2000 = 10500 minor',
      );
      debugPrint(
        'LOCAL_E2E B: admin test funding 10000 -> stake -2500 = 7500 minor; total 18000 minor',
      );
      await restartAs(tester, aToken, aRefresh);
      await openWallet(tester);
      expect(find.text('10.00 EGP · REJECTED'), findsOneWidget);
      expect(find.textContaining('STAKE_RESERVE · 25.00 EGP'), findsWidgets);
      expect(find.textContaining('STAKE_CAPTURE · 25.00 EGP'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await storage.deleteAll();
      if (oldToken != null) await storage.write(key: 'token', value: oldToken);
      if (oldRefresh != null) {
        await storage.write(key: 'refreshToken', value: oldRefresh);
      }
    }
  });
}
