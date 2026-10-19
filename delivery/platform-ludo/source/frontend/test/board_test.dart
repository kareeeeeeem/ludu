import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_club/board.dart';
import 'package:ludo_club/game/premium_board.dart';

void main() {
  test('ring is contiguous, unique and fits a 15 by 15 board', () {
    expect(ring.length, 52);
    expect(ring.toSet().length, 52);
    for (final p in ring) {
      expect(p.dx, inInclusiveRange(0, 14));
      expect(p.dy, inInclusiveRange(0, 14));
    }
    var diagonalCorners = 0;
    for (var i = 0; i < ring.length; i++) {
      final a = ring[i], b = ring[(i + 1) % ring.length];
      final dx = (a.dx - b.dx).abs(), dy = (a.dy - b.dy).abs();
      expect(dx <= 1 && dy <= 1 && dx + dy >= 1, isTrue,
        reason: 'track gap at ring index $i');
      if (dx == 1 && dy == 1) diagonalCorners++;
    }
    expect(diagonalCorners, 4);
    expect(tokenPosition('red', 0, 0), ring[13]);
    expect(tokenPosition('yellow', 0, 0), ring[39]);
    for (final color in playerColors.keys) {
      final start = tokenPosition(color, 0, 0);
      final finish = tokenPosition(color, 57, 0);
      expect(ring.contains(start), isTrue);
      expect(finish.dx, inInclusiveRange(6, 8));
      expect(finish.dy, inInclusiveRange(6, 8));
      for (var progress = 0; progress <= 57; progress++) {
        final point = tokenPosition(color, progress, 0);
        expect(point.dx, inInclusiveRange(0, 14));
        expect(point.dy, inInclusiveRange(0, 14));
      }
    }
  });
  test('every server track index maps to one visible square and each color turns into its own six-cell lane', () {
    const colors = ['red', 'green', 'yellow', 'blue'];
    const laneStarts = [Offset(7, 1), Offset(13, 7), Offset(7, 13), Offset(1, 7)];
    const laneEnds = [Offset(7, 6), Offset(8, 7), Offset(7, 8), Offset(6, 7)];
    final lanes = <Offset>{};
    for (var colorIndex = 0; colorIndex < colors.length; colorIndex++) {
      final color = colors[colorIndex];
      expect(tokenPosition(color, 0, 0), ring[(colorIndex * 13 + 13) % 52]);
      expect(tokenPosition(color, 50, 0), ring[(colorIndex * 13 + 11) % 52]);
      for (var progress = 0; progress <= 50; progress++) {
        expect(tokenPosition(color, progress, 0),
          ring[(colorIndex * 13 + progress + 13) % 52]);
      }
      expect(tokenPosition(color, 51, 0), laneStarts[colorIndex]);
      expect(tokenPosition(color, 56, 0), laneEnds[colorIndex]);
      final lastTrack = tokenPosition(color, 50, 0);
      final firstLane = tokenPosition(color, 51, 0);
      expect((lastTrack.dx - firstLane.dx).abs() + (lastTrack.dy - firstLane.dy).abs(), 1);
      for (var progress = 51; progress <= 56; progress++) {
        final cell = tokenPosition(color, progress, 0);
        expect(ring.contains(cell), isFalse);
        expect(lanes.add(cell), isTrue);
        if (progress > 51) {
          final previous = tokenPosition(color, progress - 1, 0);
          expect((cell.dx - previous.dx).abs() + (cell.dy - previous.dy).abs(), 1);
        }
      }
      final finish = tokenPosition(color, 57, 0);
      expect(finish.dx, inInclusiveRange(6, 9));
      expect(finish.dy, inInclusiveRange(6, 9));
      expect(ring.contains(finish), isFalse);
      expect(lanes.contains(finish), isFalse);
    }
    for (var global = 0; global < 52; global++) {
      final physical = ring[(global + 13) % 52];
      for (var i = 0; i < 4; i++) {
        final progress = (global - i * 13 + 52) % 52;
        if (progress <= 50) expect(tokenPosition(colors[i], progress, 0), physical);
      }
    }
  });
  testWidgets('premium board paints four colors and selects only legal pieces', (tester) async {
    int? chosen;
    final state = <String, dynamic>{'turn': 0, 'players': [
      for (final color in playerColors.keys)
        {'id': color, 'name': color, 'color': color,
          'tokens': [-1, -1, -1, -1], 'eliminated': false},
    ]};
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(width: 450,
      child: PremiumBoard(state: state, legal: const [0], onToken: (token) => chosen = token)))));
    expect(tester.takeException(), isNull);
    await tester.tap(find.bySemanticsLabel('red token 1'));
    expect(chosen, 0);
    chosen = null;
    await tester.tap(find.bySemanticsLabel('green token 1'));
    expect(chosen, isNull);
  });
  testWidgets(
    'board permits selecting only highlighted current-player tokens',
    (tester) async {
      int? chosen;
      final state = <String, dynamic>{
        'turn': 0,
        'players': [
          {
            'id': 'a',
            'name': 'Alice',
            'color': 'red',
            'tokens': [-1, -1, -1, -1],
            'eliminated': false,
          },
          {
            'id': 'b',
            'name': 'Bob',
            'color': 'yellow',
            'tokens': [-1, -1, -1, -1],
            'eliminated': false,
          },
        ],
      };
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 450,
              child: LudoBoard(
                state: state,
                legal: const [0],
                onToken: (t) => chosen = t,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.bySemanticsLabel('Alice token 1, base'));
      expect(chosen, 0);
      chosen = null;
      await tester.tap(find.bySemanticsLabel('Bob token 1, base'));
      expect(chosen, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
