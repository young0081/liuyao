import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme.dart';

/// 旋转太极 + 外圈八卦刻度。安装器的主视觉符号。
class TaijiMark extends StatefulWidget {
  const TaijiMark({super.key, this.size = 132, this.spinning = true});
  final double size;
  final bool spinning;

  @override
  State<TaijiMark> createState() => _TaijiMarkState();
}

class _TaijiMarkState extends State<TaijiMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );

  @override
  void initState() {
    super.initState();
    if (widget.spinning) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant TaijiMark oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.spinning && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.spinning && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            RotationTransition(
              turns: Tween<double>(begin: 0, end: -1).animate(_c),
              child: CustomPaint(painter: const _TickPainter()),
            ),
            RotationTransition(
              turns: _c,
              child: CustomPaint(painter: const _TaijiPainter()),
            ),
          ],
        ),
      ),
    );
  }
}

class _TickPainter extends CustomPainter {
  const _TickPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.width / 2;
    final tickPaint = Paint()
      ..color = XuanTheme.gold.withValues(alpha: 0.55)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final outer = r * 0.98;
      final inner = r * 0.86;
      final p1 = center + Offset(math.cos(a), math.sin(a)) * inner;
      final p2 = center + Offset(math.cos(a), math.sin(a)) * outer;
      canvas.drawLine(p1, p2, tickPaint);
    }

    // 鎏金外环。
    canvas.drawCircle(
      center,
      r * 0.8,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = XuanTheme.gold.withValues(alpha: 0.7),
    );
  }

  @override
  bool shouldRepaint(covariant _TickPainter oldDelegate) => false;
}

class _TaijiPainter extends CustomPainter {
  const _TaijiPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.width / 2;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    final tr = r * 0.72;

    final dark = Paint()..color = XuanTheme.inkDeep;
    final light = Paint()..color = XuanTheme.goldSoft;

    // 整圆亮底。
    canvas.drawCircle(Offset.zero, tr, light);
    // 暗半。
    final darkHalf = Path()
      ..addArc(
        Rect.fromCircle(center: Offset.zero, radius: tr),
        -math.pi / 2,
        math.pi,
      );
    canvas.drawPath(darkHalf, dark);
    // 两个小圆构成阴阳鱼。
    canvas.drawCircle(Offset(0, -tr / 2), tr / 2, dark);
    canvas.drawCircle(Offset(0, tr / 2), tr / 2, light);
    // 鱼眼。
    canvas.drawCircle(Offset(0, -tr / 2), tr / 6, light);
    canvas.drawCircle(Offset(0, tr / 2), tr / 6, dark);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TaijiPainter oldDelegate) => false;
}
