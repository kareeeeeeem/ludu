// Development-only entry point for device screenshot comparison.
// Build with: flutter run -t lib/visual_qa.dart
import 'package:flutter/material.dart';
import 'api.dart';
import 'main.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final api = Api()
    ..online = true
    ..user = {'id': 'red', 'name': 'Player 2', 'equipped': <String,String>{}}
    ..game = {
      'id': 'visual-qa', 'status': 'active', 'mode': 'classic',
      'legalMoves': <int>[], 'stakeMinor': 0,
      'state': {
        'turn': 0, 'phase': 'roll', 'lastDice': 0,
        'deadline': DateTime.now().millisecondsSinceEpoch + 30000,
        'players': [
          {'id':'red','name':'Player 2','color':'red','tokens':[-1,7,18,-1],'eliminated':false},
          {'id':'green','name':'Player 4','color':'green','tokens':[-1,4,19,-1],'eliminated':false},
          {'id':'yellow','name':'Player 3','color':'yellow','tokens':[-1,-1,3,25],'eliminated':false},
          {'id':'blue','name':'Player 1','color':'blue','tokens':[-1,5,21,-1],'eliminated':false},
        ],
      },
    };
  runApp(MaterialApp(debugShowCheckedModeBanner:false,home:GameScreen(api:api)));
}
