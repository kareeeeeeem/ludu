import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../board.dart';

/// The illustrated surface is decorative. Every route, safe square and token
/// target still comes from board.dart and the server's Classic rules.
class CraftedBoardPainter extends CustomPainter {
  const CraftedBoardPainter({required this.theme});
  final String theme;

  static const cream = Color(0xFFF1E9DB);
  static const seam = Color(0xFF807D82);
  static const sand = Color(0xFFDAB99D);
  static const safe = {0, 8, 13, 21, 26, 34, 39, 47};

  void rr(Canvas c, Rect r, Color fill, double radius, {Color? border, double stroke = 1}) {
    final shape = RRect.fromRectAndRadius(r, Radius.circular(radius));
    c.drawRRect(shape, Paint()..color = fill);
    if (border != null) c.drawRRect(shape, Paint()..color = border..style = PaintingStyle.stroke..strokeWidth = stroke);
  }

  void tile(Canvas c, Rect r, Color fill, double unit) {
    c.drawRect(r.shift(Offset(0, unit * .035)), Paint()..color = const Color(0x665B5362));
    c.drawRect(r, Paint()..color = fill);
    c.drawRect(r, Paint()..color = seam..style = PaintingStyle.stroke..strokeWidth = unit * .022);
    c.drawLine(r.topLeft + Offset(unit * .07, unit * .08), r.topRight - Offset(unit * .07, -unit * .08),
      Paint()..color = Colors.white.withValues(alpha: .55)..strokeWidth = unit * .035);
  }

  void pool(Canvas c, Path path) {
    c.drawPath(path.shift(const Offset(0, 3)), Paint()..color = const Color(0x885F777B));
    c.drawPath(path, Paint()..color = const Color(0xFFFFE6C7)..style = PaintingStyle.stroke..strokeWidth = 7);
    c.drawPath(path, Paint()..color = const Color(0xFF80D8E1));
    c.drawPath(path, Paint()..color = Colors.white.withValues(alpha: .72)..style = PaintingStyle.stroke..strokeWidth = 2);
  }

  void palm(Canvas c, Offset at, double s) {
    final trunk = Path()..moveTo(at.dx, at.dy)..quadraticBezierTo(at.dx - s * .18, at.dy - s * .5, at.dx - s * .08, at.dy - s);
    c.drawPath(trunk, Paint()..color = const Color(0xFFC06B4D)..strokeWidth = s * .16..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
    final crown = at + Offset(-s * .08, -s);
    for (var i = 0; i < 7; i++) {
      final a = i * math.pi * 2 / 7;
      final end = crown + Offset(math.cos(a) * s * .75, math.sin(a) * s * .53);
      c.drawLine(crown, end, Paint()..color = i.isEven ? const Color(0xFF257E58) : const Color(0xFF4AAE70)
        ..strokeWidth = s * .19..strokeCap = StrokeCap.round);
    }
    c.drawCircle(crown, s * .12, Paint()..color = const Color(0xFF398F5A));
  }

  void tower(Canvas c, double u) {
    rr(c, Rect.fromLTWH(.95*u, 1.5*u, 1.0*u, 3.6*u), const Color(0xFF3F9EBF), .16*u,
      border: const Color(0xFFE7D4A4), stroke: .08*u);
    for (var i = 0; i < 3; i++) {
      rr(c, Rect.fromLTWH((.78 + i*.10)*u, (2.1+i*.85)*u, 1.4*u, .22*u),
        const Color(0xFFB8E4E7), .12*u, border: const Color(0xFF58879C), stroke: .03*u);
    }
    c.drawLine(Offset(1.47*u, 1.5*u), Offset(1.47*u, 1.0*u), Paint()..color = Colors.white..strokeWidth = .06*u);
    c.drawCircle(Offset(1.47*u, 1.0*u), .09*u, Paint()..color = const Color(0xFFFFD08E));
  }

  void sailboat(Canvas c, double u) {
    final hull = Path()..moveTo(12.4*u, 4.9*u)..quadraticBezierTo(13.65*u, 5.3*u, 14.65*u, 4.8*u)
      ..lineTo(14.2*u, 5.32*u)..quadraticBezierTo(13.1*u, 5.65*u, 12.5*u, 5.23*u)..close();
    c.drawPath(hull, Paint()..color = const Color(0xFFB36C63));
    c.drawPath(hull, Paint()..color = const Color(0xFFFFF0DB)..style = PaintingStyle.stroke..strokeWidth = .06*u);
    c.drawLine(Offset(13.55*u, 4.9*u), Offset(13.55*u, 1.0*u), Paint()..color = const Color(0xFF6E7B8A)..strokeWidth = .08*u);
    final sail = Path()..moveTo(13.47*u, 1.15*u)..lineTo(12.4*u, 4.65*u)..lineTo(13.47*u, 4.4*u)..close();
    c.drawPath(sail, Paint()..color = const Color(0xFFF9F2E9));
    c.drawPath(sail, Paint()..color = const Color(0xFF83B9C9)..style = PaintingStyle.stroke..strokeWidth = .05*u);
    final sail2 = Path()..moveTo(13.68*u, 2.1*u)..lineTo(14.47*u, 4.66*u)..lineTo(13.68*u, 4.4*u)..close();
    c.drawPath(sail2, Paint()..color = const Color(0xFFD8E5E5));
  }

  void market(Canvas c, double u) {
    rr(c, Rect.fromLTWH(.35*u, 12.15*u, 2.8*u, 2.15*u), const Color(0xFFCF7046), .18*u,
      border: const Color(0xFFFFC86E), stroke: .1*u);
    final roof = Path()..moveTo(.18*u, 12.3*u)..lineTo(1.65*u, 11.75*u)..lineTo(3.3*u, 12.3*u)..close();
    c.drawPath(roof, Paint()..color = const Color(0xFFF2A441));
    for (final x in [.75, 1.6, 2.45]) {
      rr(c, Rect.fromLTWH(x*u, 13*u, .48*u, .85*u), const Color(0xFFFFD67F), .16*u);
    }
    rr(c, Rect.fromLTWH(.2*u, 9.4*u, 1.9*u, 1.8*u), const Color(0xFFE8925C), .28*u,
      border: const Color(0xFFFFD395), stroke: .1*u);
    c.drawArc(Rect.fromLTWH(.5*u, 9.65*u, 1.35*u, 1.2*u), math.pi, math.pi, false,
      Paint()..color = const Color(0xFFFECC7B)..strokeWidth = .22*u..style = PaintingStyle.stroke);
  }

  void festival(Canvas c, double u) {
    final tent = Path()..moveTo(12.0*u, 12.3*u)..lineTo(13.4*u, 10.8*u)..lineTo(14.7*u, 12.3*u)..close();
    c.drawPath(tent, Paint()..color = const Color(0xFFEB9855));
    c.drawPath(tent, Paint()..color = const Color(0xFFFFD187)..style = PaintingStyle.stroke..strokeWidth = .12*u);
    rr(c, Rect.fromLTWH(12.35*u, 12.3*u, 2.1*u, 1.15*u), const Color(0xFFCA6E51), .16*u);
    for (var i = 0; i < 3; i++) {
      rr(c, Rect.fromLTWH((10.7+i*.75)*u, 13.5*u, .48*u, .65*u),
        i.isEven ? const Color(0xFFD26C54) : const Color(0xFFFFB36E), .16*u,
        border: const Color(0xFFFFDC91), stroke: .04*u);
    }
    c.drawLine(Offset(10.2*u, 11.6*u), Offset(10.2*u, 13.6*u), Paint()..color = const Color(0xFF996749)..strokeWidth = .07*u);
    c.drawOval(Rect.fromLTWH(9.75*u, 11.7*u, .9*u, 1.15*u), Paint()..color = const Color(0xFFF6C27F));
  }

  void shield(Canvas c, Offset p, double u, Color color) {
    final path = Path()..moveTo(p.dx, p.dy-u*.27)..lineTo(p.dx+u*.24,p.dy-u*.14)
      ..lineTo(p.dx+u*.2,p.dy+u*.15)..lineTo(p.dx,p.dy+u*.31)
      ..lineTo(p.dx-u*.2,p.dy+u*.15)..lineTo(p.dx-u*.24,p.dy-u*.14)..close();
    c.drawPath(path, Paint()..color = color.withValues(alpha:.5));
    c.drawPath(path, Paint()..color = const Color(0xFF5D6270)..strokeWidth=u*.045..style=PaintingStyle.stroke);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width/15;
    final board = Offset.zero & size;
    rr(canvas, board, sand, u*.22);
    for (var q=0; q<4; q++) {
      final x = q.isOdd ? 9.0 : 0.0;
      final y = q>=2 ? 9.0 : 0.0;
      rr(canvas, Rect.fromLTWH(x*u,y*u,6*u,6*u),
        q==0 ? const Color(0xFFD6B7A2) : q==1 ? const Color(0xFFD9B69D) :
        q==2 ? const Color(0xFFDCA883) : const Color(0xFFD9AE8E),u*.1);
      for(var j=0;j<7;j++) {
        final xx=(x+.4+(j*1.57)%5.1)*u, yy=(y+.4+(j*2.17)%5.1)*u;
        canvas.drawRect(Rect.fromLTWH(xx,yy,u*.24,u*.08),Paint()..color=Colors.white.withValues(alpha:.09));
      }
    }
    pool(canvas,Path()..moveTo(3.65*u,1.55*u)..lineTo(4.65*u,1.4*u)..lineTo(5.45*u,2.25*u)
      ..lineTo(5.1*u,2.55*u)..lineTo(3.45*u,2.55*u)..close());
    pool(canvas,Path()..moveTo(.25*u,3.6*u)..lineTo(1.65*u,3.35*u)..lineTo(1.8*u,4.65*u)
      ..lineTo(.3*u,4.8*u)..close());
    pool(canvas,Path()..moveTo(12*u,.5*u)..lineTo(14.65*u,.4*u)..lineTo(14.8*u,5.15*u)
      ..lineTo(12.6*u,5*u)..close());
    tower(canvas,u); sailboat(canvas,u); market(canvas,u); festival(canvas,u);
    for(final p in [const Offset(5.25,1.25),const Offset(.75,4.8),const Offset(9.7,1.25),
                    const Offset(14.1,4.25),const Offset(4.75,12.8),const Offset(13.8,10.3)]) {
      palm(canvas,Offset(p.dx*u,p.dy*u),u*.63);
    }

    const quadrantColors = [Color(0xFFEF5576),Color(0xFF42AC5C),Color(0xFFF89A35),Color(0xFF1595D7)];
    const origins = [Offset(9,0),Offset(9,9),Offset(0,9),Offset(0,0)];
    for(var i=0;i<4;i++) {
      final origin=origins[i]; final color=quadrantColors[i];
      final left=origin.dx==0 ? 2.25 : 9.25;
      final top=origin.dy==0 ? 2.25 : 9.25;
      final r=Rect.fromLTWH(left*u,top*u,3.45*u,3.45*u);
      rr(canvas,r.shift(Offset(0,u*.10)),const Color(0x995B5362),u*.18);
      rr(canvas,r.inflate(u*.12),const Color(0xFFF8D9A6),u*.17,
        border:const Color(0xFF9D827A),stroke:u*.05);
      rr(canvas,r,color,u*.15,border:Color.lerp(color,Colors.black,.25),stroke:u*.045);
      for(var t=0;t<4;t++) {
        final p=tokenPosition(playerColors.keys.elementAt(i),-1,t);
        final center=Offset((p.dx+.42)*u,(p.dy+.42)*u);
        canvas.drawCircle(center+Offset(0,u*.04),u*.39,Paint()..color=Colors.black.withValues(alpha:.17));
        canvas.drawCircle(center,u*.38,Paint()..color=Color.lerp(color,Colors.black,.12)!);
        canvas.drawCircle(center-Offset(0,u*.035),u*.34,Paint()..color=color.withValues(alpha:.82));
        canvas.drawArc(Rect.fromCircle(center:center,radius:u*.32),math.pi*1.06,math.pi*.88,false,
          Paint()..color=Colors.white.withValues(alpha:.18)..strokeWidth=u*.025..style=PaintingStyle.stroke);
      }
      for(var n=51;n<=56;n++) {
        final p=tokenPosition(playerColors.keys.elementAt(i),n,0);
        tile(canvas,Rect.fromLTWH(p.dx*u,p.dy*u,u,u),color,u);
      }
    }
    for(var physical=0;physical<52;physical++) {
      final p=ring[physical]; final global=(physical+39)%52;
      final r=Rect.fromLTWH(p.dx*u,p.dy*u,u,u);
      tile(canvas,r,cream,u);
      if(global%13==0) {
        canvas.save(); canvas.clipRect(r.deflate(u*.055));
        canvas.drawRect(r,Paint()..color=const Color(0xFFF5C73E));
        for(var j=-1;j<4;j++) {
          final stripe=Path()..moveTo(r.left+(j*.43)*u,r.top)..lineTo(r.left+(j*.43+.22)*u,r.top)
            ..lineTo(r.left+(j*.43-.25)*u,r.bottom)..lineTo(r.left+(j*.43-.47)*u,r.bottom)..close();
          canvas.drawPath(stripe,Paint()..color=const Color(0xFF3C3740));
        }
        canvas.restore();
      } else if(safe.contains(global)) {
        shield(canvas,r.center,u,const Color(0xFFB2AABD));
      }
    }
    final center=Offset(7.5*u,7.5*u);
    final corners=[Offset(6*u,6*u),Offset(9*u,6*u),Offset(9*u,9*u),Offset(6*u,9*u)];
    for(var i=0;i<4;i++) {
      final path=Path()..moveTo(center.dx,center.dy)..lineTo(corners[(i+3)%4].dx,corners[(i+3)%4].dy)
        ..lineTo(corners[i].dx,corners[i].dy)..close();
      canvas.drawPath(path,Paint()..color=quadrantColors[(i+3)%4]);
      canvas.drawPath(path,Paint()..color=const Color(0x99564F65)..style=PaintingStyle.stroke..strokeWidth=u*.025);
    }
    canvas.drawRect(board,Paint()..color=const Color(0xFF8D8D9D)..style=PaintingStyle.stroke..strokeWidth=u*.045);
  }

  @override
  bool shouldRepaint(covariant CraftedBoardPainter oldDelegate)=>oldDelegate.theme!=theme;
}
