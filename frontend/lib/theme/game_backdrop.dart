import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Scalable, original illustrated scenery shared by every route.
class GameBackdrop extends StatelessWidget {
  const GameBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      const Positioned.fill(child: CustomPaint(painter: _BackdropPainter())),
      child,
    ],
  );
}

class _BackdropPainter extends CustomPainter {
  const _BackdropPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    canvas.drawRect(
      full,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFB9EEFF), Color(0xFFE4F8FF), Color(0xFFFFF5D6)],
          stops: [0, .56, 1],
        ).createShader(full),
    );
    final w = size.width, h = size.height;
    void cloud(double x, double y, double scale, double alpha) {
      final p = Paint()..color = Colors.white.withValues(alpha: alpha);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, y),
          width: 116 * scale,
          height: 32 * scale,
        ),
        p,
      );
      canvas.drawCircle(Offset(x - 27 * scale, y - 8 * scale), 24 * scale, p);
      canvas.drawCircle(Offset(x + 7 * scale, y - 15 * scale), 30 * scale, p);
    }

    cloud(w * .18, h * .14, .8, .64);
    cloud(w * .83, h * .29, .55, .5);
    cloud(w * .68, h * .08, .38, .4);
    final hill1 =
        Path()
          ..moveTo(0, h * .79)
          ..quadraticBezierTo(w * .24, h * .72, w * .55, h * .83)
          ..quadraticBezierTo(w * .76, h * .89, w, h * .76)
          ..lineTo(w, h)
          ..lineTo(0, h)
          ..close();
    canvas.drawPath(
      hill1,
      Paint()..color = const Color(0xFFA8E2A8).withValues(alpha: .35),
    );
    final hill2 =
        Path()
          ..moveTo(0, h * .91)
          ..quadraticBezierTo(w * .4, h * .82, w, h * .94)
          ..lineTo(w, h)
          ..lineTo(0, h)
          ..close();
    canvas.drawPath(
      hill2,
      Paint()..color = const Color(0xFF61C996).withValues(alpha: .25),
    );
    for (var i = 0; i < 24; i++) {
      final x = ((i * 73 + 31) % 101) / 101 * w;
      final y = ((i * 47 + 17) % 83) / 83 * h * .85;
      final r = i % 3 == 0 ? 3.2 : 1.8;
      final color =
          i.isEven ? const Color(0xFFFFD66F) : const Color(0xFF69BFD4);
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()..color = color.withValues(alpha: .4),
      );
      if (i % 7 == 0) {
        final path = Path();
        for (var k = 0; k < 4; k++) {
          final a = k * math.pi / 2;
          final p = Offset(x + math.cos(a) * 6, y + math.sin(a) * 6);
          if (k == 0) {
            path.moveTo(p.dx, p.dy);
          } else {
            path.lineTo(p.dx, p.dy);
          }
        }
        path.close();
        canvas.drawPath(path, Paint()..color = color.withValues(alpha: .4));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
