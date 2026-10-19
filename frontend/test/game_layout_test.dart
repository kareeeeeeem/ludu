import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_club/api.dart';
import 'package:ludo_club/main.dart';
import 'package:ludo_club/game/reference_game_scene.dart';

void main() {
  testWidgets('full private room offers host start and invite controls', (tester) async {
    final api = Api()
      ..user = {'id': 'host', 'equipped': <String, String>{}}
      ..game = {
        'id': 'room', 'status': 'waiting', 'mode': 'private', 'capacity': 2,
        'code': 'AABBCCDDEE', 'host': 'host', 'stakeMinor': 0,
        'members': ['host', 'guest'], 'names': ['Guest_1234abcd', 'Friend'],
      };
    await tester.pumpWidget(MaterialApp(home: GameScreen(api: api)));
    expect(find.text('START MATCH'), findsOneWidget);
    expect(find.text('COPY INVITE CODE'), findsOneWidget);
    expect(find.text('Player 1234'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    api.dispose();
  });
  for (final width in [320.0, 360.0]) {
    testWidgets('four-player game remains usable at ${width.toInt()}px width', (tester) async {
      tester.view.physicalSize = Size(width, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final api = Api()
        ..user = {'id': 'red', 'equipped': <String, String>{}}
        ..game = {
          'id': 'test', 'status': 'active', 'mode': 'quick', 'capacity': 4,
          'legalMoves': [0, 1, 2, 3], 'stakeMinor': 0,
          'state': {
            'turn': 0, 'phase': 'move', 'lastDice': 6, 'dice': 6,
            'deadline': DateTime.now().millisecondsSinceEpoch + 30000,
            'players': [
              for (final color in ['red', 'green', 'yellow', 'blue'])
                {'id': color, 'name': color, 'color': color,
                  'tokens': [-1, -1, -1, -1], 'eliminated': false},
            ],
          },
        };
      await tester.pumpWidget(MaterialApp(home: GameScreen(api: api)));
      expect(find.byType(ReferenceGameScene), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsNothing);
      expect(find.byIcon(Icons.mic_off_rounded), findsNothing);
      expect(find.byIcon(Icons.chat_bubble_rounded), findsOneWidget);
      expect(find.text('MOVE 1'), findsOneWidget);
      expect(find.text('MOVE 4'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      api.dispose();
    });
  }
}
