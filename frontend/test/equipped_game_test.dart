import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_club/api.dart';
import 'package:ludo_club/game/premium_board.dart';
import 'package:ludo_club/main.dart';
import 'package:ludo_club/widgets/custom_dice.dart';

void main() {
  testWidgets('each player keeps their equipped token and active dice skin', (tester) async {
    final state = <String, dynamic>{
      'turn': 1, 'phase': 'roll', 'lastDice': null,
      'deadline': DateTime.now().millisecondsSinceEpoch + 30000,
      'players': [
        {'id': 'red', 'name': 'Red', 'color': 'red', 'tokens': [-1, -1, -1, -1],
          'eliminated': false, 'equipped': {'token': 'token_classic', 'dice': 'dice_classic'}},
        {'id': 'yellow', 'name': 'Yellow', 'color': 'yellow', 'tokens': [-1, -1, -1, -1],
          'eliminated': false, 'equipped': {'token': 'token_metallic', 'dice': 'dice_gold'}},
      ],
    };
    final api = Api()
      ..user = {'id': 'red', 'equipped': {'token': 'token_classic', 'dice': 'dice_classic'}}
      ..game = {'id': 'match', 'status': 'active', 'mode': 'private', 'capacity': 2,
        'stakeMinor': 0, 'legalMoves': <int>[], 'state': state};
    await tester.pumpWidget(MaterialApp(home: GameScreen(api: api)));
    final tokens = tester.widgetList<TokenWidget>(find.byType(TokenWidget)).toList();
    expect(tokens.length, 8);
    expect(tokens.take(4).every((token) => token.styleTheme == 'token_classic'), true);
    expect(tokens.skip(4).every((token) => token.styleTheme == 'token_metallic'), true);
    expect(tester.widget<AnimatedDice>(find.byType(AnimatedDice)).diceTheme, 'dice_gold');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    api.dispose();
  });
}
