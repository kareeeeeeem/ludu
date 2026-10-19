import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Four original illustrated silhouettes matching the reference's team types.
/// They are cosmetic only; color and token identity still come from game state.
class ReferenceTokenPainter extends CustomPainter {
  const ReferenceTokenPainter({required this.colorKey, required this.active});
  final String colorKey;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final palette = switch (colorKey) {
      'blue' => (const Color(0xFF0285D6), const Color(0xFF004A9D)),
      'red' => (const Color(0xFFFF6490), const Color(0xFFB51651)),
      'green' => (const Color(0xFF39CD36), const Color(0xFF076D20)),
      _ => (const Color(0xFFFFB733), const Color(0xFFAC5712)),
    };
    if (active) {
      canvas.drawCircle(const Offset(50, 50), 48, Paint()
        ..color = const Color(0xFFFFEC65).withValues(alpha: .7)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 11));
    }
    canvas.drawOval(const Rect.fromLTWH(11, 77, 80, 17), Paint()
      ..color = Colors.black.withValues(alpha: .43)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    final base = Path()..moveTo(18, 69)..quadraticBezierTo(50, 83, 82, 69)
      ..lineTo(78, 82)..quadraticBezierTo(50, 98, 22, 82)..close();
    canvas.drawPath(base, Paint()..shader = LinearGradient(colors: [palette.$2, palette.$1, palette.$2])
      .createShader(const Rect.fromLTWH(18, 69, 64, 25)));
    canvas.drawPath(base, Paint()..color = const Color(0xFF462E43)
      ..style = PaintingStyle.stroke..strokeWidth = 3);
    if (colorKey == 'blue') {
      final sail = Path()..moveTo(55, 13)..quadraticBezierTo(34, 35, 31, 69)
        ..quadraticBezierTo(54, 67, 58, 64)..close();
      canvas.drawPath(sail, Paint()..shader = const LinearGradient(colors: [Colors.white, Color(0xFFA5DDEA), Color(0xFF376EB8)])
        .createShader(const Rect.fromLTWH(30, 12, 31, 60)));
      canvas.drawPath(sail, Paint()..color = palette.$2..style = PaintingStyle.stroke..strokeWidth = 3);
      canvas.drawLine(const Offset(60, 16), const Offset(60, 72), Paint()..color = const Color(0xFF394B77)..strokeWidth = 4);
      final jib = Path()..moveTo(64, 29)..lineTo(79, 67)..lineTo(64, 65)..close();
      canvas.drawPath(jib, Paint()..color = const Color(0xFFDDEEF0));
      canvas.drawArc(const Rect.fromLTWH(20, 66, 61, 17), 0, math.pi, false,
        Paint()..color = const Color(0xFF87E6F6)..style = PaintingStyle.stroke..strokeWidth = 4);
    } else if (colorKey == 'red') {
      canvas.drawOval(const Rect.fromLTWH(22, 46, 56, 29), Paint()..color = const Color(0xFFF2B66F));
      final frosting = Path()..moveTo(25, 54)..cubicTo(15, 42, 32, 36, 37, 37)
        ..cubicTo(35, 21, 52, 25, 49, 18)..cubicTo(64, 19, 63, 31, 65, 34)
        ..cubicTo(79, 35, 83, 47, 75, 55)..quadraticBezierTo(52, 66, 25, 54)..close();
      canvas.drawPath(frosting, Paint()..shader = const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFFFFD1DE), Color(0xFFFF75A1), Color(0xFFB81F58)])
        .createShader(const Rect.fromLTWH(20, 18, 60, 47)));
      canvas.drawPath(frosting, Paint()..color = const Color(0xFFAD315B)..style = PaintingStyle.stroke..strokeWidth = 2.5);
      canvas.drawArc(const Rect.fromLTWH(35, 34, 30, 16), math.pi, math.pi, false,
        Paint()..color = const Color(0xFFFFE2EA)..style = PaintingStyle.stroke..strokeWidth = 3);
    } else if (colorKey == 'green') {
      final figure = Path()..moveTo(43, 20)..lineTo(57, 18)..lineTo(56, 31)
        ..lineTo(72, 27)..lineTo(78, 36)..lineTo(62, 43)..lineTo(67, 56)
        ..lineTo(75, 69)..lineTo(66, 74)..lineTo(51, 59)..lineTo(37, 73)
        ..lineTo(27, 69)..lineTo(40, 52)..lineTo(40, 43)..lineTo(28, 46)
        ..lineTo(25, 36)..lineTo(42, 32)..close();
      canvas.drawPath(figure, Paint()..shader = LinearGradient(
        colors: [const Color(0xFFB1FB84), palette.$1, palette.$2])
        .createShader(const Rect.fromLTWH(25, 18, 54, 58)));
      canvas.drawPath(figure, Paint()..color = const Color(0xFF134A25)..style = PaintingStyle.stroke..strokeWidth = 3);
      canvas.drawCircle(const Offset(50, 15), 10, Paint()..color = palette.$1);
      canvas.drawCircle(const Offset(50, 15), 10, Paint()..color = const Color(0xFF134A25)
        ..style = PaintingStyle.stroke..strokeWidth = 2.5);
      canvas.drawOval(const Rect.fromLTWH(46, 10, 5, 3), Paint()..color = Colors.white);
    } else {
      canvas.drawOval(const Rect.fromLTWH(19, 30, 62, 48), Paint()..shader = const RadialGradient(
        center: Alignment(-.35, -.5), colors: [Color(0xFFFFED9F), Color(0xFFFFA718), Color(0xFF9B450F)])
        .createShader(const Rect.fromLTWH(19, 30, 62, 48)));
      canvas.drawOval(const Rect.fromLTWH(19, 30, 62, 48), Paint()..color = const Color(0xFF703E24)
        ..style = PaintingStyle.stroke..strokeWidth = 3);
      canvas.drawArc(const Rect.fromLTWH(25, 21, 51, 51), math.pi * 1.06, math.pi * .88, false,
        Paint()..color = const Color(0xFFFFDE72)..style = PaintingStyle.stroke..strokeWidth = 8);
      canvas.drawOval(const Rect.fromLTWH(28, 53, 44, 16), Paint()..color = const Color(0xFFFFF5DF));
      canvas.drawCircle(const Offset(39, 51), 3, Paint()..color = const Color(0xFF513424));
      canvas.drawCircle(const Offset(62, 51), 3, Paint()..color = const Color(0xFF513424));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ReferenceTokenPainter oldDelegate) =>
      oldDelegate.colorKey != colorKey || oldDelegate.active != active;
}

/// Original scalable pawn artwork. Skins alter finish/details; team color is
/// always retained so players remain identifiable on a crowded board.
class GlossyTokenPainter extends CustomPainter {
  const GlossyTokenPainter({
    required this.color,
    required this.style,
    required this.active,
    required this.number,
  });
  final Color color;
  final String style;
  final bool active;
  final int number;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    canvas.save();
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    canvas.scale(s / 100);
    final dark = Color.lerp(color, Colors.black, .42)!;
    final light =
        Color.lerp(color, Colors.white, style == 'token_crystal' ? .65 : .4)!;
    final rim =
        style == 'token_royal' || style == 'token_metallic'
            ? const Color(0xFFFFDA7B)
            : Colors.white;
    if (active) {
      canvas.drawCircle(
        const Offset(50, 51),
        49,
        Paint()
          ..color = const Color(0xFFFFD76E).withValues(alpha: .65)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 11),
      );
    }
    canvas.drawOval(
      const Rect.fromLTWH(9, 77, 82, 19),
      Paint()
        ..color = Colors.black.withValues(alpha: .38)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawOval(const Rect.fromLTWH(12, 65, 76, 25), Paint()..color = dark);
    canvas.drawOval(
      const Rect.fromLTWH(14, 62, 72, 22),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [light, color, dark],
        ).createShader(const Rect.fromLTWH(14, 62, 72, 22)),
    );
    canvas.drawOval(
      const Rect.fromLTWH(18, 67, 64, 13),
      Paint()
        ..color = rim.withValues(alpha: .65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    final body =
        Path()
          ..moveTo(33, 64)
          ..cubicTo(37, 49, 39, 44, 42, 37)
          ..lineTo(58, 37)
          ..cubicTo(61, 44, 63, 49, 67, 64)
          ..quadraticBezierTo(50, 74, 33, 64)
          ..close();
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [light, color, dark],
        ).createShader(const Rect.fromLTWH(30, 35, 40, 35)),
    );
    canvas.drawCircle(const Offset(50, 30), 17, Paint()..color = dark);
    canvas.drawCircle(
      const Offset(49, 27),
      16,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.42, -.48),
          radius: .9,
          colors: [Colors.white.withValues(alpha: .94), light, color, dark],
          stops: const [0, .17, .65, 1],
        ).createShader(const Rect.fromLTWH(33, 11, 32, 32)),
    );
    canvas.drawOval(
      const Rect.fromLTWH(37, 16, 9, 5),
      Paint()..color = Colors.white.withValues(alpha: .8),
    );
    if (style == 'token_crystal') {
      final facet =
          Path()
            ..moveTo(42, 44)
            ..lineTo(50, 38)
            ..lineTo(57, 45)
            ..lineTo(51, 61)
            ..close();
      canvas.drawPath(
        facet,
        Paint()..color = Colors.white.withValues(alpha: .38),
      );
    } else if (style == 'token_royal') {
      final crown =
          Path()
            ..moveTo(34, 14)
            ..lineTo(31, 4)
            ..lineTo(41, 9)
            ..lineTo(50, 2)
            ..lineTo(59, 9)
            ..lineTo(69, 4)
            ..lineTo(66, 14)
            ..close();
      canvas.drawPath(crown, Paint()..color = const Color(0xFFFFD76E));
    } else if (style == 'token_neon') {
      canvas.drawOval(
        const Rect.fromLTWH(20, 70, 60, 12),
        Paint()
          ..color = Colors.cyanAccent.withValues(alpha: .9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    } else if (style == 'token_metallic') {
      canvas.drawArc(
        const Rect.fromLTWH(24, 62, 52, 17),
        .2,
        math.pi * .8,
        false,
        Paint()
          ..color = const Color(0xFFFFE7AE)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
    final label = TextPainter(
      text: TextSpan(
        text: '$number',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w900,
          shadows: [Shadow(color: Colors.black87, blurRadius: 3)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, Offset(50 - label.width / 2, 53 - label.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GlossyTokenPainter oldDelegate) =>
      color != oldDelegate.color ||
      style != oldDelegate.style ||
      active != oldDelegate.active ||
      number != oldDelegate.number;
}
