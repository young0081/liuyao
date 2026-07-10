import 'package:flutter/material.dart';
import 'theme.dart';
import 'widgets/taiji_loader.dart';
import 'widgets/title_bar.dart';

/// 启动引导：先显示太极加载动画，再淡出交给主界面。
class SplashGate extends StatefulWidget {
  const SplashGate({super.key, required this.child});

  final Widget child;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1350), () {
      if (!mounted) return;
      setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: XuanMotion.page,
      switchInCurve: XuanMotion.emphasized,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        fit: StackFit.expand,
        children: [...previousChildren, ?currentChild],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.992, end: 1).animate(animation),
          child: child,
        ),
      ),
      child: _ready
          ? KeyedSubtree(key: const ValueKey('home'), child: widget.child)
          : const _SplashScreen(key: ValueKey('splash')),
    );
  }
}

class _SplashScreen extends StatefulWidget {
  const _SplashScreen({super.key});

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: _intro, curve: Curves.easeOutCubic);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        color: XuanTheme.inkDeep,
        child: Column(
          children: [
            const XuanTitleBar(showSettings: false),
            Expanded(
              child: Center(
                child: FadeTransition(
                  opacity: fade,
                  child: AnimatedBuilder(
                    animation: fade,
                    builder: (_, child) => Transform.translate(
                      offset: Offset(0, (1 - fade.value) * 16),
                      child: child,
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RepaintBoundary(child: TaijiLoader(size: 96)),
                        SizedBox(height: 26),
                        Text(
                          '玄机 · 六爻卦象',
                          style: TextStyle(
                            color: XuanTheme.textMain,
                            fontSize: 21,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 9),
                        Text(
                          '凝神静气 · 起卦以观其象',
                          style: TextStyle(
                            color: XuanTheme.textMuted,
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(height: 28),
                        _LoadTrack(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadTrack extends StatelessWidget {
  const _LoadTrack();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1250),
      curve: XuanMotion.ease,
      builder: (context, value, _) => SizedBox(
        width: 144,
        height: 2,
        child: Stack(
          children: [
            const Positioned.fill(child: ColoredBox(color: XuanTheme.lineSoft)),
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: value,
                child: const SizedBox.expand(
                  child: ColoredBox(color: XuanTheme.gold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
