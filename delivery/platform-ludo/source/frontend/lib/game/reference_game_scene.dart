import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../board.dart';
import '../widgets/custom_dice.dart';
import 'premium_board.dart';

/// Portrait match composition based on the supplied 900×1600 reference.
/// All controls receive authoritative state and callbacks from GameScreen.
class ReferenceGameScene extends StatelessWidget {
  const ReferenceGameScene({super.key, required this.state, required this.legal,
    required this.me, required this.points, required this.seconds,
    required this.canRoll, required this.busy, required this.online,
    required this.diceValue, required this.diceTheme, required this.boardTheme,
    required this.tokenTheme, required this.onRoll, required this.onMove,
    required this.onMenu, required this.onChat});
  final Map<String,dynamic> state;
  final List<dynamic> legal;
  final String? me;
  final dynamic points;
  final int seconds, diceValue;
  final bool canRoll, busy, online;
  final String diceTheme, boardTheme, tokenTheme;
  final VoidCallback onRoll, onMenu, onChat;
  final void Function(int)? onMove;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
    final w=box.maxWidth, h=box.maxHeight;
    final side=math.min(w*.955,h*.53);
    final boardTop=(h*.237).clamp(112.0, h-side-120.0);
    final boardLeft=(w-side)/2;
    final avatar=math.min(w*.125,56.0);
    final players=(state['players'] as List?) ?? [];
    Map? player(String color) {
      for(final p in players) { if(p['color']==color) return p as Map; }
      return null;
    }
    bool current(Map? p) => p != null && players.indexOf(p)==state['turn'];
    final font=math.min(w*.028,13.0);
    Widget seat(String color, Alignment alignment, bool lower) {
      final p=player(color);
      final label=p == null ? 'Waiting' : _friendly(p['name']?.toString() ?? 'Player');
      final active=current(p);
      return Positioned(
        top: lower ? boardTop+side+math.min(h*.047,45) : math.max(72,h*.086),
        left: alignment==Alignment.centerLeft ? w*.086 : null,
        right: alignment==Alignment.centerRight ? w*.086 : null,
        child: Column(children: [
          SizedBox(width:avatar,height:avatar,child:Stack(children:[Container(width:avatar,height:avatar,decoration:BoxDecoration(shape:BoxShape.circle,
            gradient:const LinearGradient(colors:[Color(0xFFA5FBFF),Color(0xFF138DC4)]),
            border:Border.all(color:active?const Color(0xFFFFDA54):const Color(0xFF8BE8FF),width:3),
            boxShadow:[BoxShadow(color:active?const Color(0xFFFFDA54):Colors.black38,
              blurRadius:active?15:7,offset:const Offset(0,3))]),
            padding:const EdgeInsets.all(3),
            child:ClipOval(child:CustomPaint(painter:PortraitPainter(color:playerColors[color]??Colors.blue,
              variant:color)))),
            if(active) Positioned(left:0,top:0,child:Container(
              padding:const EdgeInsets.symmetric(horizontal:4,vertical:1),
              decoration:BoxDecoration(color:seconds<=5?const Color(0xFFAE3142):const Color(0xFF0C5984),
                borderRadius:BorderRadius.circular(7),border:Border.all(color:Colors.white,width:1)),
              child:Text('${seconds}s',style:TextStyle(color:Colors.white,fontSize:font*.72,
                fontWeight:FontWeight.w900)))),
          ])),
          const SizedBox(height:3),
          Text(label,style:TextStyle(color:Colors.white,fontSize:font+1,fontWeight:FontWeight.w900,
            fontStyle:FontStyle.italic,shadows:const [Shadow(color:Colors.black87,blurRadius:3,offset:Offset(1,2))])),
        ]),
      );
    }
    return Stack(children:[
      Positioned.fill(child:CustomPaint(painter:GameBackgroundPainter())),
      Positioned(left:w*.018,top:5,child:RoundGameButton(icon:Icons.menu_rounded,size:math.min(w*.105,48),onTap:onMenu)),
      Positioned(right:w*.022,top:8,child:Container(height:39,padding:const EdgeInsets.only(left:30,right:10),
        decoration:BoxDecoration(color:const Color(0xFF092F53),borderRadius:BorderRadius.circular(14),
          border:Border.all(color:const Color(0xFF537DA0),width:2),boxShadow:const [BoxShadow(color:Colors.black38,blurRadius:4)]),
        child:Row(children:[Text(points is num?'$points':'—',style:const TextStyle(color:Colors.white,fontSize:21,
          fontWeight:FontWeight.w900,fontStyle:FontStyle.italic)),const SizedBox(width:9),
          const Icon(Icons.add_circle,color:Color(0xFF5BD83B),size:24)]))),
      Positioned(right:w*.022+88,top:3,child:Transform.rotate(angle:.65,
        child:Container(width:33,height:33,decoration:BoxDecoration(gradient:const LinearGradient(
          colors:[Color(0xFFFF8FFF),Color(0xFFCB27E6),Color(0xFF7427AF)]),
          borderRadius:BorderRadius.circular(6),border:Border.all(color:const Color(0xFFFBC5FF),width:2))))),
      seat('blue',Alignment.centerLeft,false),
      seat('red',Alignment.centerRight,false),
      Positioned(left:boardLeft,top:boardTop,width:side,height:side,
        child:PremiumBoard(state:state,legal:legal,onToken:onMove,boardTheme:boardTheme,tokenTheme:tokenTheme)),
      seat('yellow',Alignment.centerLeft,true),
      seat('green',Alignment.centerRight,true),
      Positioned(left:w*.105,top:boardTop+side+math.min(h*.026,24),child:Row(children:[
        AnimatedDice(value:diceValue,isRolling:busy,size:math.min(28,w*.055),diceTheme:diceTheme,
          onTap:canRoll&&!busy?onRoll:null),const SizedBox(width:4),
        Text(diceValue==0?'·':'$diceValue',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w900))])),
      Positioned(
        left:w/2-39, top:boardTop+side+math.min(h*.016,17),
        child:GestureDetector(
          onTap:canRoll&&!busy?onRoll:null,
          child:Container(
            width:78,height:78,padding:const EdgeInsets.all(9),
            decoration:BoxDecoration(borderRadius:BorderRadius.circular(23),
              gradient:const LinearGradient(colors:[Color(0xFF68E8FF),Color(0xFF0077BA),Color(0xFF004874)]),
              boxShadow:const [BoxShadow(color:Colors.black54,blurRadius:9,offset:Offset(0,7))]),
            child:Container(
              decoration:BoxDecoration(borderRadius:BorderRadius.circular(15),
                gradient:const LinearGradient(colors:[Color(0xFFAE5D44),Color(0xFF69392E)]),
                border:Border.all(color:const Color(0xFFE4AD73),width:3)),
              child:Center(child:CustomPaint(size:const Size(43,43),painter:ActionEmblemPainter())),
            ),
          ),
        ),
      ),
      if(state['phase']=='move'&&legal.isNotEmpty&&onMove!=null)
        Positioned(left:w*.12,right:w*.12,top:boardTop+side+math.min(h*.105,100),child:Wrap(
          alignment:WrapAlignment.center,spacing:4,runSpacing:4,children:[for(final token in legal.take(4))
            Padding(padding:const EdgeInsets.symmetric(horizontal:2),child:InkWell(
              onTap:()=>onMove!(token as int),child:Container(padding:const EdgeInsets.all(5),
              decoration:BoxDecoration(color:const Color(0xFFFFD260),borderRadius:BorderRadius.circular(8)),
              child:Text('MOVE ${token+1}',style:const TextStyle(fontSize:9,fontWeight:FontWeight.w900)))))])),
      Positioned(left:w*.10,bottom:math.max(9,h*.017),child:Row(children:[
        RoundGameButton(icon:Icons.emoji_emotions_rounded,size:math.min(w*.10,48),onTap:null),
        SizedBox(width:w*.035),RoundGameButton(icon:Icons.chat_bubble_rounded,size:math.min(w*.10,48),onTap:onChat)])),
      if(!online) Positioned(top:52,left:0,right:0,child:Center(child:Container(
        padding:const EdgeInsets.symmetric(horizontal:12,vertical:4),
        decoration:BoxDecoration(color:const Color(0xFF8F3349),borderRadius:BorderRadius.circular(12)),
        child:const Text('Reconnecting…',style:TextStyle(color:Colors.white))))),
    ]);
  });

  String _friendly(String s) => s.startsWith('Guest_')?'Player ${s.substring(6,math.min(10,s.length))}':s;
}

class RoundGameButton extends StatelessWidget {
  const RoundGameButton({super.key,required this.icon,required this.size,this.onTap});
  final IconData icon; final double size; final VoidCallback? onTap;
  @override Widget build(BuildContext context)=>InkWell(onTap:onTap,customBorder:const CircleBorder(),
    child:Opacity(opacity:onTap==null ? .55 : 1,child:Container(width:size,height:size,
      decoration:BoxDecoration(shape:BoxShape.circle,gradient:const LinearGradient(
        begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Color(0xFFFFF0A5),Color(0xFFC68124),Color(0xFFFFD770)]),
        border:Border.all(color:const Color(0xFF684727),width:2),
        boxShadow:const [BoxShadow(color:Colors.black45,blurRadius:6,offset:Offset(0,4))]),
      padding:EdgeInsets.all(size*.09),child:Container(decoration:BoxDecoration(shape:BoxShape.circle,
        gradient:const LinearGradient(colors:[Color(0xFF78E8FC),Color(0xFF138FC8),Color(0xFF085786)]),
        border:Border.all(color:const Color(0xFFE7FFFF),width:2)),
        child:Icon(icon,color:Colors.white,size:size*.48,shadows:const [Shadow(color:Color(0xFF075175),blurRadius:2,offset:Offset(1,2))])))));
}

class GameBackgroundPainter extends CustomPainter {
  @override void paint(Canvas c,Size s) {
    c.drawRect(Offset.zero&s,Paint()..shader=const LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,
      colors:[Color(0xFF164778),Color(0xFF1E5C91),Color(0xFF174A7C)]).createShader(Offset.zero&s));
    final p=Paint()..color=const Color(0x12A7D7EC)..style=PaintingStyle.stroke..strokeWidth=1.2;
    for(var x=-40.0;x<s.width+50;x+=78) {for(var y=20.0;y<s.height;y+=105){
      final dx=x+(y.toInt()%3)*19;
      c.save();c.translate(dx,y);c.rotate((x+y)*.003);
      c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(0,0,40,25),const Radius.circular(6)),p);
      c.drawCircle(const Offset(11,13),5,p);c.drawLine(const Offset(23,9),const Offset(34,9),p);
      c.restore();
    }}
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate)=>false;
}

class ActionEmblemPainter extends CustomPainter {
  @override void paint(Canvas c, Size s) {
    c.save(); c.translate(s.width/2,s.height/2);
    for(var i=0;i<3;i++) {
      c.save(); c.rotate(i*math.pi*2/3);
      final path=Path()..moveTo(0,2)..cubicTo(12,0,18,-7,13,-15)
        ..cubicTo(9,-22,-1,-17,3,-11)..cubicTo(5,-8,9,-11,8,-14);
      c.drawPath(path,Paint()..color=const Color(0xFF7D4B22)..style=PaintingStyle.stroke
        ..strokeWidth=8..strokeCap=StrokeCap.round);
      c.drawPath(path,Paint()..color=const Color(0xFFFFD267)..style=PaintingStyle.stroke
        ..strokeWidth=5..strokeCap=StrokeCap.round);
      c.restore();
    }
    c.restore();
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate)=>false;
}

class PortraitPainter extends CustomPainter {
  const PortraitPainter({required this.color,required this.variant});
  final Color color; final String variant;
  @override void paint(Canvas c,Size s) {
    c.save();c.scale(s.width/100,s.height/100);
    c.drawRect(const Rect.fromLTWH(0,0,100,100),Paint()..shader=LinearGradient(colors:[color.withValues(alpha:.65),const Color(0xFF3B519E)])
      .createShader(const Rect.fromLTWH(0,0,100,100)));
    c.drawOval(const Rect.fromLTWH(9,70,82,55),Paint()..color=color);
    c.drawOval(const Rect.fromLTWH(23,14,55,66),Paint()..color=const Color(0xFF794A30));
    c.drawOval(const Rect.fromLTWH(27,20,47,58),Paint()..color=variant=='red'?const Color(0xFFC88A60):const Color(0xFFDAA074));
    c.drawArc(const Rect.fromLTWH(19,9,62,63),math.pi,math.pi,false,
      Paint()..color=variant=='blue'?const Color(0xFF522263):const Color(0xFF332127)..style=PaintingStyle.stroke..strokeWidth=15);
    for(final x in [39.0,62.0]) { c.drawCircle(Offset(x,49),2.5,Paint()..color=const Color(0xFF28201F)); }
    c.drawArc(const Rect.fromLTWH(42,51,21,14),0,math.pi,false,Paint()..color=const Color(0xFF7B312E)..style=PaintingStyle.stroke..strokeWidth=2);
    c.restore();
  }
  @override bool shouldRepaint(covariant PortraitPainter old)=>old.color!=color||old.variant!=variant;
}
