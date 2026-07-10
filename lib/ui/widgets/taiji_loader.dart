import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// 旋转的太极加载动画：一圈流动的鎏金弧光 + 中央缓慢旋转的阴阳鱼。
class TaijiLoader extends StatefulWidget {
  const TaijiLoader({super.key, this.size = 64, this.label});

  final double size;
  final String? label;

  @override
  State<TaijiLoader> createState() => _TaijiLoaderState();
}

class _TaijiLoaderState extends State<TaijiLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5200),
  )..repeat();
  // 同一周期内外圈转两周、太极反转一周，首尾均落在完整圈数上。
  late final Animation<double> _arcTurns = Tween<double>(
    begin: 0,
    end: 2,
  ).animate(_c);
  late final Animation<double> _taijiTurns = Tween<double>(
    begin: 0,
    end: -1,
  ).animate(_c);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: RepaintBoundary(
            child: Stack(
              fit: StackFit.expand,
              children: [
                RotationTransition(
                  turns: _arcTurns,
                  child: CustomPaint(painter: const _ArcPainter()),
                ),
                RotationTransition(
                  turns: _taijiTurns,
                  child: CustomPaint(painter: const _TaijiPainter()),
                ),
              ],
            ),
          ),
        ),
        if (widget.label != null) ...[
          const SizedBox(height: 14),
          _PulsingLabel(text: widget.label!, animation: _c),
        ],
      ],
    );
  }
}

class _PulsingLabel extends StatelessWidget {
  const _PulsingLabel({required this.text, required this.animation});
  final String text;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final pulse = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.55,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.55,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.55,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.55,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
    ]).animate(animation);
    return FadeTransition(
      opacity: pulse,
      child: Text(
        text,
        style: const TextStyle(color: XuanTheme.goldSoft, fontSize: 12.5),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: 2 * math.pi,
        colors: const [
          Color(0x00C7A24B),
          Color(0x66C7A24B),
          Color(0xFFD9BE7E),
          Color(0x00C7A24B),
        ],
        stops: const [0.0, 0.55, 0.8, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r - 3, arcPaint);
  }

  @override
  bool shouldRepaint(covariant _ArcPainter oldDelegate) => false;
}

class _TaijiPainter extends CustomPainter {
  const _TaijiPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    final tr = r * 0.62;

    final light = Paint()..color = XuanTheme.goldSoft;
    final dark = Paint()..color = XuanTheme.ink;

    // 底：亮半 + 暗半。
    canvas.drawCircle(Offset.zero, tr, light);
    final darkHalf = Path()
      ..addArc(
        Rect.fromCircle(center: Offset.zero, radius: tr),
        -math.pi / 2,
        math.pi,
      );
    canvas.drawPath(darkHalf, dark);

    // 上小圆(暗) 下小圆(亮)。
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

/// 首帧淡入 + 轻微上移，用于结果/面板内容出现时的过渡。
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 420),
    this.offset = 12,
  });

  final Widget child;
  final Duration duration;
  final double offset;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..forward();

  late final Animation<double> _fade = CurvedAnimation(
    parent: _c,
    curve: Curves.easeOutCubic,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: AnimatedBuilder(
        animation: _fade,
        builder: (_, child) => Transform.translate(
          offset: Offset(0, (1 - _fade.value) * widget.offset),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// 逐条错峰淡入上移，用于列表项（如六爻、历史）的入场。
class StaggeredReveal extends StatefulWidget {
  const StaggeredReveal({
    super.key,
    required this.index,
    required this.child,
    this.baseDelay = const Duration(milliseconds: 55),
    this.duration = const Duration(milliseconds: 380),
    this.offset = 14,
  });

  final int index;
  final Widget child;
  final Duration baseDelay;
  final Duration duration;
  final double offset;

  @override
  State<StaggeredReveal> createState() => _StaggeredRevealState();
}

class _StaggeredRevealState extends State<StaggeredReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    final delay = widget.baseDelay * widget.index;
    final total = delay + widget.duration;
    final start = total.inMicroseconds == 0
        ? 0.0
        : delay.inMicroseconds / total.inMicroseconds;
    _c = AnimationController(vsync: this, duration: total)..forward();
    _anim = CurvedAnimation(
      parent: _c,
      curve: Interval(start, 1, curve: XuanMotion.emphasized),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) => Opacity(
        opacity: _anim.value,
        child: Transform.translate(
          offset: Offset(0, (1 - _anim.value) * widget.offset),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// 缓慢的呼吸缩放/透明，用于空态占位符等静态元素的“活”起来。
class Breathing extends StatefulWidget {
  const Breathing({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 2600),
    this.minScale = 0.94,
    this.minOpacity = 0.55,
  });

  final Widget child;
  final Duration duration;
  final double minScale;
  final double minOpacity;

  @override
  State<Breathing> createState() => _BreathingState();
}

class _BreathingState extends State<Breathing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..repeat(reverse: true);
  late final Animation<double> _t = CurvedAnimation(
    parent: _c,
    curve: Curves.easeInOut,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: widget.minOpacity, end: 1).animate(_t),
      child: ScaleTransition(
        scale: Tween<double>(begin: widget.minScale, end: 1).animate(_t),
        child: widget.child,
      ),
    );
  }
}

/// 打字机：逐字揭示目标文本。流式场景里，上游可能一次送来多字，
/// 这里在 UI 层节流，做到“一字一字”的观感；文本追加时自然续写。
class Typewriter extends StatefulWidget {
  const Typewriter({
    super.key,
    required this.text,
    required this.style,
    this.active = true,
    this.showCursor = true,
    this.tick = const Duration(milliseconds: 26),
    this.onTap,
  });

  /// 目标全文（可持续增长）。
  final String text;
  final TextStyle style;

  /// 是否仍在生成中（决定是否显示光标、是否继续推进）。
  final bool active;
  final bool showCursor;
  final Duration tick;
  final VoidCallback? onTap;

  @override
  State<Typewriter> createState() => _TypewriterState();
}

class _TypewriterState extends State<Typewriter> {
  Timer? _timer;
  int _visible = 0;

  @override
  void initState() {
    super.initState();
    _ensureTimer();
  }

  @override
  void didUpdateWidget(covariant Typewriter old) {
    super.didUpdateWidget(old);
    // 新文本若不是在旧文本基础上续写（切换卦例/重新生成），则回到起点重放。
    final isContinuation =
        widget.text.length >= old.text.length &&
        widget.text.startsWith(old.text);
    if (!isContinuation || _visible > widget.text.length) {
      _visible = 0;
    }
    _ensureTimer();
  }

  void _ensureTimer() {
    if (_visible >= widget.text.length) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    _timer ??= Timer.periodic(widget.tick, (_) {
      if (!mounted) return;
      if (_visible >= widget.text.length) {
        _timer?.cancel();
        _timer = null;
        if (mounted) setState(() {});
        return;
      }
      // 落后太多时略微加速，避免显示长时间滞后于已收到的内容。
      final gap = widget.text.length - _visible;
      final step = gap > 60 ? (gap / 30).ceil() : 1;
      setState(() => _visible = (_visible + step).clamp(0, widget.text.length));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shown = widget.text.substring(
      0,
      _visible.clamp(0, widget.text.length),
    );
    final caughtUp = _visible >= widget.text.length;
    final showCursor = widget.showCursor && (widget.active || !caughtUp);
    final content = Text.rich(
      TextSpan(
        text: shown,
        style: widget.style,
        children: showCursor
            ? [
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: _BlinkingCursor(
                    color: widget.style.color ?? XuanTheme.gold,
                  ),
                ),
              ]
            : null,
      ),
    );
    if (widget.onTap == null) return content;
    return GestureDetector(onTap: widget.onTap, child: content);
  }
}

class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor({required this.color});
  final Color color;

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final on = _c.value < 0.5;
        return Opacity(
          opacity: on ? 1 : 0.05,
          child: Container(
            width: 7,
            height: 15,
            margin: const EdgeInsets.only(left: 2),
            color: widget.color.withValues(alpha: 0.8),
          ),
        );
      },
    );
  }
}
