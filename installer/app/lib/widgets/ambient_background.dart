import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme.dart';

/// 沉浸式动态背景：径向墨色渐变 + 缓慢漂移的星点与卦爻符号。
class AmbientBackground extends StatefulWidget {
  const AmbientBackground({super.key, this.intensity = 1.0});

  /// 粒子活跃度（安装进行时可调高）。
  final double intensity;

  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 30),
  )..repeat();

  late final List<_Particle> _particles = _seed(46);

  List<_Particle> _seed(int n) {
    final rnd = math.Random(2026);
    return List.generate(n, (_) {
      return _Particle(
        x: rnd.nextDouble(),
        y: rnd.nextDouble(),
        speed: 0.15 + rnd.nextDouble() * 0.5,
        radius: 0.6 + rnd.nextDouble() * 1.8,
        phase: rnd.nextDouble() * math.pi * 2,
        gold: rnd.nextDouble() > 0.35,
      );
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) => CustomPaint(
          painter: _AmbientPainter(
            _c.value,
            _particles,
            widget.intensity,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _Particle {
  _Particle({
    required this.x,
    required this.y,
    required this.speed,
    required this.radius,
    required this.phase,
    required this.gold,
  });
  final double x;
  final double y;
  final double speed;
  final double radius;
  final double phase;
  final bool gold;
}

class _AmbientPainter extends CustomPainter {
  _AmbientPainter(this.t, this.particles, this.intensity);
  final double t;
  final List<_Particle> particles;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    // 底色径向渐变。
    final bg = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.2, -0.35),
        radius: 1.2,
        colors: [Color(0xFF1A222D), Color(0xFF0C0F14)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);

    // 漂移星点。
    for (final p in particles) {
      final y = (p.y - t * p.speed) % 1.0;
      final twinkle = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(p.phase + t * 6));
      final color = (p.gold ? XuanTheme.gold : XuanTheme.textMain)
          .withValues(alpha: 0.10 + 0.35 * twinkle * intensity);
      canvas.drawCircle(
        Offset(p.x * size.width, y * size.height),
        p.radius,
        Paint()..color = color,
      );
    }

    // 右下角淡卦象爻线（装饰）。
    final linePaint = Paint()
      ..color = XuanTheme.gold.withValues(alpha: 0.05 + 0.03 * intensity)
      ..strokeWidth = 10;
    final baseX = size.width * 0.72;
    final baseY = size.height * 0.30;
    final w = size.width * 0.22;
    for (var i = 0; i < 6; i++) {
      final yy = baseY + i * 34.0;
      if (i.isEven) {
        canvas.drawLine(Offset(baseX, yy), Offset(baseX + w, yy), linePaint);
      } else {
        canvas.drawLine(
            Offset(baseX, yy), Offset(baseX + w * 0.42, yy), linePaint);
        canvas.drawLine(Offset(baseX + w * 0.58, yy), Offset(baseX + w, yy),
            linePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientPainter old) =>
      old.t != t || old.intensity != intensity;
}
