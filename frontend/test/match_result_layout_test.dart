import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_club/game/match_result_modal.dart';

void main() {
  testWidgets('completed match remains scrollable on a short phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MatchResultModal(
            isWin: false,
            winnerName: 'Bot 1',
            stakeMinor: 0,
            prizePoolMinor: 0,
            pointsMode: true,
            onPlayAgain: () {},
            onBackHome: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -250),
    );
    await tester.pumpAndSettle();
    expect(find.text('BACK TO HOME'), findsOneWidget);
  });
}
