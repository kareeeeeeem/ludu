import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_club/game/game_menu_sheet.dart';

void main() {
  testWidgets('game options scroll on a short phone and forfeit stays reachable', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    var forfeits = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (context) =>
      TextButton(onPressed: () => showModalBottomSheet<void>(
        context: context, isScrollControlled: true,
        builder: (_) => GameMenuSheet(
          soundEnabled: true, hapticsEnabled: true,
          onToggleSound: () {}, onToggleHaptics: () {},
          onForfeit: () => forfeits++, onReportProblem: () {},
        ),
      ), child: const Text('Open menu'))))));
    await tester.tap(find.text('Open menu'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('FORFEIT MATCH'));
    await tester.tap(find.text('FORFEIT MATCH'));
    await tester.pumpAndSettle();
    expect(forfeits, 1);
    expect(tester.takeException(), isNull);
  });
}
