import 'package:flutter/material.dart';

const playerColors = {
  'red': Color(0xFFEF5576),
  'green': Color(0xFF43B862),
  'yellow': Color(0xFFFF9C32),
  'blue': Color(0xFF168FD6),
};
const ring = <Offset>[
  Offset(1, 6),
  Offset(2, 6),
  Offset(3, 6),
  Offset(4, 6),
  Offset(5, 6),
  Offset(6, 5),
  Offset(6, 4),
  Offset(6, 3),
  Offset(6, 2),
  Offset(6, 1),
  Offset(6, 0),
  Offset(7, 0),
  Offset(8, 0),
  Offset(8, 1),
  Offset(8, 2),
  Offset(8, 3),
  Offset(8, 4),
  Offset(8, 5),
  Offset(9, 6),
  Offset(10, 6),
  Offset(11, 6),
  Offset(12, 6),
  Offset(13, 6),
  Offset(14, 6),
  Offset(14, 7),
  Offset(14, 8),
  Offset(13, 8),
  Offset(12, 8),
  Offset(11, 8),
  Offset(10, 8),
  Offset(9, 8),
  Offset(8, 9),
  Offset(8, 10),
  Offset(8, 11),
  Offset(8, 12),
  Offset(8, 13),
  Offset(8, 14),
  Offset(7, 14),
  Offset(6, 14),
  Offset(6, 13),
  Offset(6, 12),
  Offset(6, 11),
  Offset(6, 10),
  Offset(6, 9),
  Offset(5, 8),
  Offset(4, 8),
  Offset(3, 8),
  Offset(2, 8),
  Offset(1, 8),
  Offset(0, 8),
  Offset(0, 7),
  Offset(0, 6),
];
Offset tokenPosition(String color, int progress, int token) {
  final index = playerColors.keys.toList().indexOf(color);
  if (progress == -1) {
    final origin =
        [
          const Offset(9, 0),
          const Offset(9, 9),
          const Offset(0, 9),
          const Offset(0, 0),
        ][index];
    final leftSide = origin.dx == 0;
    final topSide = origin.dy == 0;
    return origin + Offset(
      (leftSide ? 2.8 : .8) + (token.isOdd ? 1.2 : 0),
      (topSide ? 2.8 : .8) + (token >= 2 ? 1.2 : 0),
    );
  }
  // Rotate the visual route one quadrant clockwise. The server's global
  // square index and collision mapping remain unchanged.
  if (progress <= 50) return ring[(index * 13 + progress + 13) % 52];
  if (progress == 57) {
    return const [Offset(7, 6.15), Offset(7.85, 7), Offset(7, 7.85), Offset(6.15, 7)][index];
  }
  final n = (progress - 51).toDouble();
  return [
    Offset(7, 1 + n),
    Offset(13 - n, 7),
    Offset(7, 13 - n),
    Offset(1 + n, 7),
  ][index];
}

class LudoBoard extends StatelessWidget {
  const LudoBoard({
    super.key,
    required this.state,
    this.legal = const [],
    this.onToken,
  });
  final Map<String, dynamic> state;
  final List<dynamic> legal;
  final void Function(int)? onToken;
  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1,
    child: LayoutBuilder(
      builder: (context, box) {
        final cell = box.maxWidth / 15;
        final players = state['players'] as List;
        final occupied = <String, int>{};
        return ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              const Positioned.fill(
                child: CustomPaint(painter: BoardPainter()),
              ),
              for (var p = 0; p < players.length; p++)
                for (var t = 0; t < 4; t++)
                  (() {
                    final player = players[p];
                    final progress = player['tokens'][t] as int;
                    final pos = tokenPosition(player['color'], progress, t);
                    final key = '${pos.dx}:${pos.dy}';
                    final stack = occupied.update(
                      key,
                      (v) => v + 1,
                      ifAbsent: () => 0,
                    );
                    final movable =
                        p == state['turn'] &&
                        legal.contains(t) &&
                        onToken != null;
                    return AnimatedPositioned(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeInOutCubic,
                      left: (pos.dx + .1) * cell + (stack % 2) * cell * .22,
                      top: (pos.dy + .1) * cell + (stack ~/ 2) * cell * .18,
                      width: cell * .8,
                      height: cell * .8,
                      child: Semantics(
                        excludeSemantics: true,
                        label:
                            '${player['name']} token ${t + 1}, ${progress == -1
                                ? 'base'
                                : progress == 57
                                ? 'finished'
                                : 'step $progress'}',
                        button: movable,
                        child: GestureDetector(
                          onTap: movable ? () => onToken!(t) : null,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: playerColors[player['color']]!.withValues(
                                alpha: player['eliminated'] == true ? .35 : 1,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                    movable
                                        ? const Color(0xFF1D2736)
                                        : Colors.white,
                                width: movable ? 3 : 2,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x33000000),
                                  blurRadius: 3,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: FittedBox(
                                child: Text(
                                  '${t + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  })(),
            ],
          ),
        );
      },
    ),
  );
}

class BoardPainter extends CustomPainter {
  const BoardPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.width / 15;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF9F7F0),
    );
    final origins = [
      const Offset(9, 0),
      const Offset(9, 9),
      const Offset(0, 9),
      Offset.zero,
    ];
    final colors = playerColors.values.toList();
    for (var i = 0; i < 4; i++) {
      canvas.drawRect(
        Rect.fromLTWH(origins[i].dx * c, origins[i].dy * c, 6 * c, 6 * c),
        Paint()..color = colors[i],
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            (origins[i].dx + .8) * c,
            (origins[i].dy + .8) * c,
            4.4 * c,
            4.4 * c,
          ),
          Radius.circular(c * .6),
        ),
        Paint()..color = Colors.white.withValues(alpha: .9),
      );
      for (var t = 0; t < 4; t++) {
        final p = tokenPosition(playerColors.keys.elementAt(i), -1, t);
        canvas.drawCircle(
          Offset((p.dx + .5) * c, (p.dy + .5) * c),
          c * .5,
          Paint()..color = colors[i].withValues(alpha: .2),
        );
      }
      for (var n = 51; n <= 56; n++) {
        final p = tokenPosition(playerColors.keys.elementAt(i), n, 0);
        canvas.drawRect(
          Rect.fromLTWH(p.dx * c, p.dy * c, c, c),
          Paint()..color = colors[i].withValues(alpha: .65),
        );
      }
    }
    for (var i = 0; i < ring.length; i++) {
      final p = ring[i];
      final rect = Rect.fromLTWH(p.dx * c, p.dy * c, c, c);
      if (i % 13 == 0) canvas.drawRect(rect, Paint()..color = colors[(i ~/ 13 + 3) % 4]);
      canvas.drawRect(
        rect,
        Paint()
          ..color = const Color(0xFFDADDDC)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .65,
      );
      if ([0, 8, 13, 21, 26, 34, 39, 47].contains(i)) {
        final text = TextPainter(
          text: const TextSpan(
            text: '✦',
            style: TextStyle(color: Color(0xFF697579), fontSize: 13),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        text.paint(
          canvas,
          Offset(
            (p.dx + .5) * c - text.width / 2,
            (p.dy + .5) * c - text.height / 2,
          ),
        );
      }
    }
    final center = Offset(7.5 * c, 7.5 * c);
    for (var i = 0; i < 4; i++) {
      final corners = [
        Offset(6 * c, 6 * c),
        Offset(9 * c, 6 * c),
        Offset(9 * c, 9 * c),
        Offset(6 * c, 9 * c),
      ];
      final path =
          Path()
            ..moveTo(center.dx, center.dy)
            ..lineTo(corners[(i + 3) % 4].dx, corners[(i + 3) % 4].dy)
            ..lineTo(corners[i].dx, corners[i].dy)
            ..close();
      canvas.drawPath(path, Paint()..color = colors[(i + 3) % 4]);
    }
  }

  @override
  bool shouldRepaint(covariant BoardPainter oldDelegate) => false;
}
