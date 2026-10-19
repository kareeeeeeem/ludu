import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GameMenuSheet extends StatefulWidget {
  const GameMenuSheet({
    super.key,
    required this.soundEnabled,
    required this.hapticsEnabled,
    required this.onToggleSound,
    required this.onToggleHaptics,
    required this.onForfeit,
    required this.onReportProblem,
  });

  final bool soundEnabled;
  final bool hapticsEnabled;
  final VoidCallback onToggleSound;
  final VoidCallback onToggleHaptics;
  final VoidCallback onForfeit;
  final VoidCallback onReportProblem;

  @override
  State<GameMenuSheet> createState() => _GameMenuSheetState();
}

class _GameMenuSheetState extends State<GameMenuSheet> {
  late bool _sound;
  late bool _haptics;

  @override
  void initState() {
    super.initState();
    _sound = widget.soundEnabled;
    _haptics = widget.hapticsEnabled;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.glassBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'GAME OPTIONS',
              style: TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              secondary: Icon(
                _sound ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                color: AppColors.gold,
              ),
              title: const Text('Sound Effects'),
              value: _sound,
              onChanged: (_) {
                setState(() => _sound = !_sound);
                widget.onToggleSound();
              },
            ),
            SwitchListTile(
              secondary: Icon(
                _haptics ? Icons.vibration_rounded : Icons.mobile_off_rounded,
                color: AppColors.emerald,
              ),
              title: const Text('Haptic Feedback'),
              value: _haptics,
              onChanged: (_) {
                setState(() => _haptics = !_haptics);
                widget.onToggleHaptics();
              },
            ),
            ListTile(
              leading: const Icon(Icons.rule_rounded, color: Colors.cyanAccent),
              title: const Text('Ludo Rules'),
              onTap: () {
                final navigatorContext = Navigator.of(context).context;
                Navigator.pop(context);
                showDialog<void>(
                  context: navigatorContext,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Ludo Rules'),
                    content: const SingleChildScrollView(
                      child: Text(
                        '1. Roll 6 to move a token out of your home base.\n'
                        '2. Rolling 6 grants an extra roll.\n'
                        '3. Landing on an opponent returns their piece home (unless on a Star safe cell).\n'
                        '4. Get all 4 tokens around the board into the center Home triangle to win!\n'
                        '5. Three consecutive 6s lose your turn.',
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Got it'),
                      ),
                    ],
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.report_problem_outlined, color: Colors.orangeAccent),
              title: const Text('Report a Problem'),
              onTap: () {
                Navigator.pop(context);
                widget.onReportProblem();
              },
            ),
            const Divider(color: AppColors.glassBorder, height: 24),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                widget.onForfeit();
              },
              icon: const Icon(Icons.flag_rounded, color: AppColors.ruby),
              label: const Text(
                'FORFEIT MATCH',
                style: TextStyle(color: AppColors.ruby, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.ruby),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
