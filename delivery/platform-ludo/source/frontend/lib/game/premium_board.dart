import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../board.dart';
import 'board_surface.dart';
import 'token_art.dart';

class PremiumBoard extends StatelessWidget {
  const PremiumBoard({
    super.key,
    required this.state,
    this.legal = const [],
    this.onToken,
    this.boardTheme = 'board_classic',
    this.tokenTheme = 'token_classic',
  });

  final Map<String, dynamic> state;
  final List<dynamic> legal;
  final void Function(int)? onToken;
  final String boardTheme;
  final String tokenTheme;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, box) {
          final frame = box.maxWidth * .026;
          final cell = (box.maxWidth - frame * 2) / 15;
          final players = state['players'] as List;
          final occupied = <String, int>{};

          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(box.maxWidth * .055),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFE8E9F2), Color(0xFF9CA6C7), Color(0xFFE1E3EF)],
              ),
              border: Border.all(color: const Color(0xFF8B91B1), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .44),
                  blurRadius: 15,
                  offset: const Offset(0, 9),
                ),
              ],
            ),
            padding: EdgeInsets.all(frame),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(box.maxWidth * .029),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: CraftedBoardPainter(theme: boardTheme),
                    ),
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
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOutBack,
                          left:
                              (pos.dx - .045) * cell + (stack % 2) * cell * .22,
                          top:
                              (pos.dy - .045) * cell + (stack ~/ 2) * cell * .18,
                          width: cell * 1.09,
                          height: cell * 1.09,
                          child: Semantics(
                            label: '${player['name']} token ${t + 1}',
                            button: movable,
                            child: GestureDetector(
                              onTap: movable ? () => onToken!(t) : null,
                              child: TokenWidget(
                                colorKey: player['color'],
                                tokenNumber: t + 1,
                                isMovable: movable,
                                isEliminated: player['eliminated'] == true,
                                styleTheme: (player['equipped'] is Map
                                        ? player['equipped']['token']?.toString()
                                        : null) ??
                                    tokenTheme,
                              ),
                            ),
                          ),
                        );
                      })(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class TokenWidget extends StatefulWidget {
  const TokenWidget({
    super.key,
    required this.colorKey,
    required this.tokenNumber,
    this.isMovable = false,
    this.isEliminated = false,
    this.styleTheme = 'token_classic',
  });

  final String colorKey;
  final int tokenNumber;
  final bool isMovable;
  final bool isEliminated;
  final String styleTheme;

  @override
  State<TokenWidget> createState() => _TokenWidgetState();
}

class _TokenWidgetState extends State<TokenWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulse = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.isMovable) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant TokenWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isMovable && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isMovable && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color get _color => playerColors[widget.colorKey] ?? Colors.red;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final scale = widget.isMovable ? _pulse.value : 1.0;
        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: widget.isEliminated ? .48 : 1,
            child: CustomPaint(
              painter: widget.styleTheme == 'token_classic'
                  ? ReferenceTokenPainter(colorKey: widget.colorKey, active: widget.isMovable)
                  : GlossyTokenPainter(
                      color: _color,
                      style: widget.styleTheme,
                      active: widget.isMovable,
                      number: widget.tokenNumber,
                    ),
            ),
          ),
        );
      },
    );
  }
}

class PremiumBoardPainter extends CustomPainter {
  const PremiumBoardPainter({required this.theme});

  final String theme;

  Color get _baseBg {
    switch (theme) {
      case 'board_royal':
        return const Color(0xFF1E1035);
      case 'board_midnight':
        return const Color(0xFF0F172A);
      case 'board_neon':
        return const Color(0xFF0D0221);
      case 'board_luxury':
        return const Color(0xFF1F1A08);
      default:
        return const Color(0xFF1E293B);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.width / 15;
    canvas.drawRect(Offset.zero & size, Paint()..color = _baseBg);

    final origins = [
      Offset.zero,
      const Offset(9, 0),
      const Offset(9, 9),
      const Offset(0, 9),
    ];
    final colors = playerColors.values.toList();

    for (var i = 0; i < 4; i++) {
      final color = colors[i];

      // Base home square
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(origins[i].dx * c, origins[i].dy * c, 6 * c, 6 * c),
          Radius.circular(c * 0.4),
        ),
        Paint()..color = color.withValues(alpha: 0.9),
      );

      // Inner white container
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
        Paint()..color = Colors.white.withValues(alpha: 0.95),
      );

      // Token bases inside home
      for (var t = 0; t < 4; t++) {
        final p = tokenPosition(playerColors.keys.elementAt(i), -1, t);
        canvas.drawCircle(
          Offset((p.dx + .5) * c, (p.dy + .5) * c),
          c * .5,
          Paint()..color = color.withValues(alpha: 0.3),
        );
      }

      // Finish path cells
      for (var n = 52; n <= 57; n++) {
        final p = tokenPosition(playerColors.keys.elementAt(i), n, 0);
        canvas.drawRect(
          Rect.fromLTWH(p.dx * c, p.dy * c, c, c),
          Paint()..color = color.withValues(alpha: 0.85),
        );
      }
    }

    // Outer cells
    for (var i = 0; i < ring.length; i++) {
      final p = ring[i];
      final rect = Rect.fromLTWH(p.dx * c, p.dy * c, c, c);

      if (i % 13 == 0) {
        canvas.drawRect(rect, Paint()..color = colors[i ~/ 13]);
      } else {
        canvas.drawRect(
          rect,
          Paint()..color = Colors.white.withValues(alpha: 0.12),
        );
      }

      canvas.drawRect(
        rect,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8,
      );

      // Safe spot star
      if ([0, 8, 13, 21, 26, 34, 39, 47].contains(i)) {
        final text = TextPainter(
          text: const TextSpan(
            text: '★',
            style: TextStyle(
              color: AppColors.gold,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
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

    // Board Center Triangles
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
      canvas.drawPath(path, Paint()..color = colors[i]);
    }
  }

  @override
  bool shouldRepaint(covariant PremiumBoardPainter oldDelegate) =>
      oldDelegate.theme != theme;
}
