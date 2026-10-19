import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_club/api.dart';
import 'package:ludo_club/main.dart';

class AdminApi extends Api {
  final actions = <String>[];
  Map<String, dynamic>? lastBody;
  String receivingNumber = '01004632660';
  String status = 'PENDING';
  @override
  Future<dynamic> call(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    if (path == '/admin/settings/payment' && method == 'PUT') {
      actions.add(path);
      lastBody = body;
      receivingNumber = body!['vodafoneCashReceivingNumber'];
      return {'vodafoneCashReceivingNumber': receivingNumber};
    }
    if (path == '/admin/settings/payment') {
      return {'vodafoneCashReceivingNumber': receivingNumber};
    }
    if (method == 'PUT') {
      actions.add(path);
      status = 'APPROVED';
      return {'status': status};
    }
    if (path.startsWith('/admin/deposits')) {
      return [
        {
          'status': status,
          '_id': 'deposit1',
          'amountMinor': 2500,
          'userId': 'player1',
          'requestId': 'request1',
          'createdAt': '2026-09-27',
          'senderPhone': '01000000000',
          'transferReference': 'LOCAL-TEST',
        },
      ];
    }
    if (path.startsWith('/admin/analytics')) {
      return {
        'users': 1,
        'activeGames': 0,
        'completedGames': 0,
        'queued': 0,
        'pendingDeposits': 1,
        'pendingWithdrawals': 0,
        'disputes': 0,
        'modes': [],
        'dailyGames': [],
      };
    }
    return [];
  }
}

void main() {
  testWidgets(
    'admin deposit review requires reason and submits protected approval route',
    (tester) async {
      final api = AdminApi();
      await tester.pumpWidget(MaterialApp(home: AdminScreen(api: api)));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('DEPOSITS').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Approve verified transfer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Approve verified transfer'));
      await tester.pumpAndSettle();
      expect(api.actions, isEmpty);
      await tester.enterText(
        find.byType(TextField).last,
        'Verified local test reference',
      );
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(api.actions, ['/admin/deposits/deposit1/approve']);
      api.dispose();
    },
  );

  testWidgets(
    'Admin Payment Settings edits backend number, not Flutter source',
    (tester) async {
      final api = AdminApi();
      await tester.pumpWidget(MaterialApp(home: AdminScreen(api: api)));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SETTINGS').last);
      await tester.pumpAndSettle();
      expect(find.text('01004632660'), findsOneWidget);
      await tester.tap(find.text('Edit receiving number'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '01000000000');
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).last,
        'Controlled local test change',
      );
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(api.actions, ['/admin/settings/payment']);
      expect(api.lastBody?['vodafoneCashReceivingNumber'], '01000000000');
      expect(find.text('01000000000'), findsOneWidget);
      api.dispose();
    },
  );
}
