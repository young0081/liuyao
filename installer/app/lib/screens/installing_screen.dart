import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/taiji.dart';
import 'action_style.dart';

/// 第三步：安装进行中。旋转太极 + 环形进度 + 实时日志。
class InstallingScreen extends StatelessWidget {
  const InstallingScreen({
    super.key,
    required this.progress,
    required this.message,
    required this.log,
    required this.error,
    required this.onRetry,
    required this.onQuit,
  });

  final double progress;
  final String message;
  final List<String> log;
  final String? error;
  final VoidCallback onRetry;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return _ErrorView(error: error!, onRetry: onRetry, onQuit: onQuit);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(56, 8, 56, 40),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Center(
              child: _ProgressRing(progress: progress),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 5,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '正在安装',
                  style: TextStyle(
                    color: XuanTheme.textMain,
                    fontSize: 20,
                    letterSpacing: 5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: const TextStyle(
                      color: XuanTheme.gold, fontSize: 13, letterSpacing: 1),
                ),
                const SizedBox(height: 18),
                _LogPanel(log: log),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const TaijiMark(size: 118),
          SizedBox(
            width: 190,
            height: 190,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut,
              builder: (_, value, child) => CustomPaint(
                painter: _ArcPainter(value),
              ),
            ),
          ),
          Positioned(
            bottom: 6,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 350),
              builder: (_, value, child) => Text(
                '${(value * 100).round()}%',
                style: const TextStyle(
                  color: XuanTheme.textMain,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = XuanTheme.line;
    canvas.drawArc(rect.deflate(4), 0, 2 * math.pi, false, track);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        colors: [XuanTheme.gold, XuanTheme.goldSoft, XuanTheme.gold],
      ).createShader(rect);
    canvas.drawArc(
      rect.deflate(4),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _ArcPainter old) => old.progress != progress;
}

class _LogPanel extends StatelessWidget {
  const _LogPanel({required this.log});
  final List<String> log;

  @override
  Widget build(BuildContext context) {
    final recent = log.length > 6 ? log.sublist(log.length - 6) : log;
    return Container(
      height: 160,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: XuanTheme.ink.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: XuanTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          for (var i = 0; i < recent.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Text(
                    i == recent.length - 1 ? '›' : ' ',
                    style: const TextStyle(
                        color: XuanTheme.gold, fontSize: 12.5),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      recent[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: i == recent.length - 1
                            ? XuanTheme.textMain
                            : XuanTheme.textDim,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.error,
    required this.onRetry,
    required this.onQuit,
  });
  final String error;
  final VoidCallback onRetry;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(56, 20, 56, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline, color: XuanTheme.cinnabar, size: 26),
              SizedBox(width: 12),
              Text(
                '安装未能完成',
                style: TextStyle(
                  color: XuanTheme.textMain,
                  fontSize: 20,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: XuanTheme.ink.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: XuanTheme.cinnabar.withValues(alpha: 0.4)),
            ),
            child: Text(
              error,
              style: const TextStyle(color: XuanTheme.textDim, fontSize: 12.5,
                  height: 1.6),
            ),
          ),
          const Spacer(),
          Row(
            children: [
              GoldButton(
                label: '退出',
                color: XuanTheme.textDim,
                filled: false,
                onTap: onQuit,
              ),
              const Spacer(),
              GoldButton(
                label: '重试',
                icon: Icons.refresh,
                color: XuanTheme.cinnabar,
                onTap: onRetry,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
