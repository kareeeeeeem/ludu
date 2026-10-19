import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../wallet_screen.dart';
import '../widgets/premium_button.dart';

class MatchResultModal extends StatelessWidget {
  const MatchResultModal({
    super.key,
    required this.isWin,
    required this.winnerName,
    required this.stakeMinor,
    required this.prizePoolMinor,
    this.pointsMode = false,
    this.winnerPoints = 0,
    this.settlementStatus,
    required this.onPlayAgain,
    required this.onBackHome,
  });

  final bool isWin;
  final String winnerName;
  final int stakeMinor;
  final int prizePoolMinor;
  final bool pointsMode;
  final int winnerPoints;
  final String? settlementStatus;
  final VoidCallback onPlayAgain;
  final VoidCallback onBackHome;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        isWin
                            ? AppColors.gold.withValues(alpha: 0.2)
                            : AppColors.glassBorder,
                  ),
                  child: Icon(
                    isWin
                        ? Icons.emoji_events_rounded
                        : Icons.sports_score_rounded,
                    size: 56,
                    color: isWin ? AppColors.gold : AppColors.mutedInk,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isWin ? 'VICTORY!' : 'MATCH ENDED',
                  style: TextStyle(
                    color: isWin ? AppColors.gold : AppColors.ink,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isWin ? 'Winner: You!' : 'Winner: $winnerName',
                  style: const TextStyle(
                    color: AppColors.mutedInk,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'Stake Entry',
                              style: TextStyle(color: AppColors.mutedInk),
                            ),
                          ),
                          Text(
                            stakeMinor == 0
                                ? 'FREE'
                                : pointsMode
                                ? '$stakeMinor points'
                                : egp(stakeMinor),
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              pointsMode ? 'Winner award' : 'Prize Pool',
                              style: const TextStyle(color: AppColors.mutedInk),
                            ),
                          ),
                          Text(
                            pointsMode
                                ? (stakeMinor == 0
                                    ? 'FREE'
                                    : '$winnerPoints points')
                                : prizePoolMinor == 0
                                ? 'FREE'
                                : egp(prizePoolMinor),
                            style: const TextStyle(
                              color: AppColors.emerald,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (pointsMode && settlementStatus == 'SETTLING')
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      'Platform settlement pending',
                      style: TextStyle(color: AppColors.mutedInk),
                    ),
                  ),
                const SizedBox(height: 24),
                PremiumButton(
                  label: 'NEW GAME',
                  icon: Icons.replay_rounded,
                  onPressed: onPlayAgain,
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: onBackHome,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.ink,
                    side: const BorderSide(color: AppColors.glassBorder),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('BACK TO HOME'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
