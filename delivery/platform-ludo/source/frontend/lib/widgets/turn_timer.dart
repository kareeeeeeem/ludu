import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TurnTimerRing extends StatelessWidget {
  const TurnTimerRing({
    super.key,
    required this.secondsRemaining,
    this.totalSeconds = 30,
    this.size = 64,
  });

  final int secondsRemaining;
  final int totalSeconds;
  final double size;

  @override
  Widget build(BuildContext context) {
    final progress = (secondsRemaining / totalSeconds).clamp(0.0, 1.0);
    final isLow = secondsRemaining <= 5;
    final color = isLow
        ? AppColors.ruby
        : secondsRemaining <= 10
            ? AppColors.playerYellow
            : AppColors.emerald;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 5,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          AnimatedScale(
            scale: isLow ? 1.15 : 1.0,
            duration: const Duration(milliseconds: 300),
            child: Text(
              '${secondsRemaining}s',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: size * 0.28,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
