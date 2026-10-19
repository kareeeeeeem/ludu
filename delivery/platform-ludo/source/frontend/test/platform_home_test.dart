import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_club/api.dart';
import 'package:ludo_club/main.dart';
import 'package:ludo_club/widgets/premium_button.dart';

class _PlatformApi extends Api {
  @override
  Future<dynamic> call(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    if (path == '/shop/catalog') return {'catalog': <dynamic>[]};
    throw StateError('Unexpected request: $path');
  }
}

void main() {
  testWidgets(
    'platform player lands on the game home with points and no local finance',
    (tester) async {
      final api =
          _PlatformApi()
            ..user = {
              'id': 'game-profile',
              'displayName': 'Club Player',
              'avatar': '🎲',
              'platformPlayer': true,
              'points': 250,
              'available': true,
              'inventory': <String>[],
              'equipped': <String, String>{},
            };
      await tester.pumpWidget(MaterialApp(home: ClubHome(api: api)));
      await tester.pump();
      expect(find.text('Club Player'), findsWidgets);
      expect(find.text('250 Platform Points'), findsOneWidget);
      expect(find.byTooltip('Return to platform'), findsOneWidget);
      expect(find.text('LOGIN'), findsNothing);
      expect(find.text('DEPOSIT'), findsNothing);
    expect(find.text('WITHDRAW'), findsNothing);
    await tester.tap(find.text('PROFILE').last);
    await tester.pump();
    expect(find.text('Edit Name'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      api.dispose();
    },
  );
  testWidgets('Play tab exposes queue cancellation and disables conflicting entries', (tester) async {
    final api = _PlatformApi()..user = {
      'id': 'qa', 'displayName': 'QA Player', 'platformPlayer': true,
      'points': 175, 'available': true, 'activeGame': 'queue',
      'inventory': <String>[], 'equipped': <String, String>{},
    };
    await tester.pumpWidget(MaterialApp(home: ClubHome(api: api)));
    await tester.tap(find.text('PLAY').last);
    await tester.pump();
    expect(find.text('CANCEL SEARCH'), findsWidgets);
    final quick = tester.widget<PremiumButton>(find.widgetWithText(PremiumButton, 'QUICK MATCH'));
    expect(quick.onPressed, isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    api.dispose();
  });
}
