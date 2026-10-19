import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AnimatedDice extends StatefulWidget {
  const AnimatedDice({
    super.key,
    required this.value,
    this.isRolling = false,
    this.size = 64,
    this.onTap,
    this.diceTheme = 'dice_classic',
  });

  final int value;
  final bool isRolling;
  final double size;
  final VoidCallback? onTap;
  final String diceTheme;

  @override
  State<AnimatedDice> createState() => _AnimatedDiceState();
}

class _AnimatedDiceState extends State<AnimatedDice>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _rotation = Tween<double>(
      begin: 0,
      end: math.pi * 4,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
  }

  @override
  void didUpdateWidget(covariant AnimatedDice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.isRolling && !oldWidget.isRolling) ||
        (oldWidget.value != widget.value && !oldWidget.isRolling)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _primaryColor {
    switch (widget.diceTheme) {
      case 'dice_gold':
        return AppColors.gold;
      case 'dice_diamond':
        return Colors.cyanAccent;
      case 'dice_neon':
        return Colors.limeAccent;
      case 'dice_fire':
        return Colors.orangeAccent;
      default:
        return Colors.white;
    }
  }

  Color get _dotColor {
    switch (widget.diceTheme) {
      case 'dice_gold':
        return Colors.black;
      case 'dice_diamond':
        return Colors.blue.shade900;
      case 'dice_neon':
        return Colors.purple.shade900;
      case 'dice_fire':
        return Colors.deepOrange.shade900;
      default:
        return AppColors.ink;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _rotation,
        builder: (context, child) {
          final progress = _controller.value;
          // Intermediate faces are a visual sequence only. The revealed face
          // is always the authoritative value received from the server.
          final val =
              _controller.isAnimating && !reducedMotion
                  ? 1 + ((progress * 18).floor() % 6)
                  : (widget.value > 0 ? widget.value : 1);
          return Transform.translate(
            offset: Offset(
              0,
              reducedMotion
                  ? 0
                  : -math.sin(progress * math.pi) * widget.size * .22,
            ),
            child: Transform.rotate(
              angle: reducedMotion ? 0 : _rotation.value,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.size * 0.22),
                  gradient: RadialGradient(
                    center: const Alignment(-.5, -.65),
                    radius: 1.15,
                    colors: [
                      Colors.white,
                      _primaryColor,
                      Color.lerp(_primaryColor, Colors.black, .3)!,
                    ],
                    stops: const [0, .35, 1],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryColor.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: CustomPaint(
                  painter: DiceDotsPainter(value: val, dotColor: _dotColor),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class DiceDotsPainter extends CustomPainter {
  DiceDotsPainter({required this.value, required this.dotColor});

  final int value;
  final Color dotColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = dotColor;
    final r = size.width * 0.09;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final left = size.width * 0.28;
    final right = size.width * 0.72;
    final top = size.height * 0.28;
    final bottom = size.height * 0.72;

    void draw(double x, double y) => canvas.drawCircle(Offset(x, y), r, paint);

    if (value == 1) {
      draw(cx, cy);
    } else if (value == 2) {
      draw(left, top);
      draw(right, bottom);
    } else if (value == 3) {
      draw(left, top);
      draw(cx, cy);
      draw(right, bottom);
    } else if (value == 4) {
      draw(left, top);
      draw(right, top);
      draw(left, bottom);
      draw(right, bottom);
    } else if (value == 5) {
      draw(left, top);
      draw(right, top);
      draw(cx, cy);
      draw(left, bottom);
      draw(right, bottom);
    } else if (value == 6) {
      draw(left, top);
      draw(right, top);
      draw(left, cy);
      draw(right, cy);
      draw(left, bottom);
      draw(right, bottom);
    }
  }

  @override
  bool shouldRepaint(covariant DiceDotsPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.dotColor != dotColor;
}
