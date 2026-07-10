import 'package:flutter/material.dart';

import '../theme.dart';

/// 安装器背景：静态暖墨底与低对比卦线纹理，不参与逐帧重绘。
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({super.key, this.intensity = 1.0});

  final double intensity;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: XuanTheme.inkDeep,
      child: CustomPaint(
        painter: _AmbientPainter(intensity),
        size: Size.infinite,
      ),
    );
  }
}

class _AmbientPainter extends CustomPainter {
  const _AmbientPainter(this.intensity);

  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = XuanTheme.textMain.withValues(alpha: 0.018)
      ..strokeWidth = 1;
    const grid = 64.0;
    for (var x = 0.0; x <= size.width; x += grid) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = 0.0; y <= size.height; y += grid) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final linePaint = Paint()
      ..color = XuanTheme.gold.withValues(alpha: 0.035 + 0.015 * intensity)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final baseX = size.width * 0.73;
    final baseY = size.height * 0.34;
    final width = size.width * 0.18;
    for (var i = 0; i < 6; i++) {
      final y = baseY + i * 28.0;
      if (i.isEven) {
        canvas.drawLine(Offset(baseX, y), Offset(baseX + width, y), linePaint);
      } else {
        canvas.drawLine(
          Offset(baseX, y),
          Offset(baseX + width * 0.42, y),
          linePaint,
        );
        canvas.drawLine(
          Offset(baseX + width * 0.58, y),
          Offset(baseX + width, y),
          linePaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientPainter oldDelegate) =>
      oldDelegate.intensity != intensity;
}
