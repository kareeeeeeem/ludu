import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../board.dart';

class PlayerHudCard extends StatelessWidget {
  const PlayerHudCard({
    super.key,
    required this.name,
    required this.colorKey,
    required this.avatar,
    this.isCurrentTurn = false,
    this.isMe = false,
    this.isEliminated = false,
    this.frameTheme = 'frame_bronze',
  });

  final String name;
  final String colorKey;
  final String avatar;
  final bool isCurrentTurn;
  final bool isMe;
  final bool isEliminated;
  final String frameTheme;

  Color get _color => playerColors[colorKey] ?? Colors.white;

  Color get _frameBorderColor {
    switch (frameTheme) {
      case 'frame_gold':
        return AppColors.gold;
      case 'frame_silver':
        return Colors.blueGrey.shade200;
      case 'frame_diamond':
        return Colors.cyanAccent;
      default:
        return const Color(0xFFCD7F32);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isCurrentTurn
            ? _color.withValues(alpha: 0.25)
            : AppColors.surfaceDark.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentTurn ? _color : AppColors.glassBorder,
          width: isCurrentTurn ? 2.5 : 1.0,
        ),
        boxShadow: isCurrentTurn
            ? [
                BoxShadow(
                  color: _color.withValues(alpha: 0.5),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _frameBorderColor, width: 2),
            ),
            child: Text(avatar, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _color,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isEliminated ? AppColors.mutedInk : AppColors.ink,
                          fontWeight: isCurrentTurn ? FontWeight.w900 : FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                if (isCurrentTurn)
                  Text(
                    isMe ? 'YOUR TURN' : 'PLAYING',
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
