import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../install_engine.dart';
import '../theme.dart';
import 'action_style.dart';

/// 第四步：完成。
class DoneScreen extends StatefulWidget {
  const DoneScreen({
    super.key,
    required this.action,
    required this.version,
    required this.installDir,
    required this.onLaunchAndClose,
    required this.onClose,
  });

  final InstallAction action;
  final String version;
  final String installDir;
  final Future<void> Function() onLaunchAndClose;
  final VoidCallback onClose;

  @override
  State<DoneScreen> createState() => _DoneScreenState();
}

class _DoneScreenState extends State<DoneScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 820),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = ActionStyle.of(widget.action);
    final status = switch (widget.action) {
      InstallAction.update => '更新完成',
      InstallAction.rollback => '回退完成',
      InstallAction.reinstall => '修复完成',
      InstallAction.fresh => '安装完成',
    };
    final result = switch (widget.action) {
      InstallAction.update => '已更新',
      InstallAction.rollback => '已回退',
      InstallAction.reinstall => '已修复',
      InstallAction.fresh => '已安装',
    };
    final reveal = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.72, curve: XuanMotion.emphasized),
    );
    final sealReveal = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.18, 1, curve: XuanMotion.emphasized),
    );
    final slide = Tween<Offset>(
      begin: const Offset(-0.025, 0),
      end: Offset.zero,
    ).animate(reveal);

    return Padding(
      padding: const EdgeInsets.fromLTRB(64, 16, 64, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 792),
          child: Row(
            children: [
              Expanded(
                flex: 8,
                child: FadeTransition(
                  opacity: reveal,
                  child: SlideTransition(
                    position: slide,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _StatusLabel(label: status, color: style.color),
                        const SizedBox(height: 15),
                        Text(
                          '玄机 · 六爻卦象 $result',
                          style: const TextStyle(
                            color: XuanTheme.textMain,
                            fontSize: 27,
                            height: 1.25,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '程序已就绪，可以立即开始使用。',
                          style: TextStyle(
                            color: XuanTheme.textMuted,
                            fontSize: 12.5,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 22),
                        _InstallSummary(
                          version: widget.version,
                          installDir: widget.installDir,
                        ),
                        const SizedBox(height: 26),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GoldButton(
                              label: '关闭安装器',
                              icon: Icons.close_rounded,
                              color: XuanTheme.textDim,
                              filled: false,
                              onTap: widget.onClose,
                            ),
                            const SizedBox(width: 12),
                            GoldButton(
                              label: '立即启动',
                              icon: Icons.play_arrow_rounded,
                              color: style.color,
                              onTap: () => widget.onLaunchAndClose(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 38),
              Container(width: 1, height: 238, color: XuanTheme.lineSoft),
              const SizedBox(width: 38),
              Expanded(
                flex: 5,
                child: FadeTransition(
                  opacity: sealReveal,
                  child: ScaleTransition(
                    scale: Tween<double>(
                      begin: 0.94,
                      end: 1,
                    ).animate(sealReveal),
                    child: Semantics(
                      image: true,
                      label: status,
                      child: RepaintBoundary(
                        child: AnimatedBuilder(
                          animation: sealReveal,
                          builder: (context, child) => CustomPaint(
                            size: const Size.square(184),
                            painter: _SuccessSealPainter(
                              color: style.color,
                              progress: sealReveal.value,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 22, height: 1, color: color),
        const SizedBox(width: 9),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _InstallSummary extends StatelessWidget {
  const _InstallSummary({required this.version, required this.installDir});

  final String version;
  final String installDir;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: XuanTheme.lineSoft),
        ),
      ),
      child: Column(
        children: [
          _SummaryRow(label: '版本', value: 'v$version'),
          const Divider(height: 1),
          _SummaryRow(label: '安装位置', value: installDir, tooltip: installDir),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value, this.tooltip});

  final String label;
  final String value;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final valueText = Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: XuanTheme.textMain,
        fontSize: 12,
        height: 1.4,
      ),
    );
    return SizedBox(
      height: 38,
      child: Row(
        children: [
          SizedBox(
            width: 68,
            child: Text(
              label,
              style: const TextStyle(color: XuanTheme.textDim, fontSize: 11.5),
            ),
          ),
          Expanded(
            child: tooltip == null
                ? valueText
                : Tooltip(message: tooltip!, child: valueText),
          ),
        ],
      ),
    );
  }
}

class _SuccessSealPainter extends CustomPainter {
  const _SuccessSealPainter({required this.color, required this.progress});

  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) * 0.34;

    canvas.drawCircle(
      center,
      radius + 20,
      Paint()..color = color.withValues(alpha: 0.035 * progress),
    );
    canvas.drawCircle(
      center,
      radius - 8,
      Paint()..color = color.withValues(alpha: 0.075 * progress),
    );

    final quietRing = Paint()
      ..color = color.withValues(alpha: 0.24 * progress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, radius - 8, quietRing);

    final ring = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      ring,
    );

    final tickPaint = Paint()
      ..color = color.withValues(alpha: 0.72 * progress)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.square;
    for (var i = 0; i < 6; i++) {
      final angle = -math.pi / 2 + i * math.pi / 3;
      final inner = Offset(
        center.dx + math.cos(angle) * (radius + 8),
        center.dy + math.sin(angle) * (radius + 8),
      );
      final outer = Offset(
        center.dx + math.cos(angle) * (radius + 17),
        center.dy + math.sin(angle) * (radius + 17),
      );
      canvas.drawLine(inner, outer, tickPaint);
    }

    final checkProgress = ((progress - 0.38) / 0.62).clamp(0.0, 1.0);
    final check = Path()
      ..moveTo(center.dx - 28, center.dy)
      ..lineTo(center.dx - 8, center.dy + 20)
      ..lineTo(center.dx + 34, center.dy - 25);
    final metric = check.computeMetrics().first;
    final visibleCheck = metric.extractPath(0, metric.length * checkProgress);
    canvas.drawPath(
      visibleCheck,
      Paint()
        ..color = XuanTheme.goldSoft.withValues(alpha: progress)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SuccessSealPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.progress != progress;
  }
}
