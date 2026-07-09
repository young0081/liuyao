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

class _SplashGateState extends State<SplashGate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1900), () async {
      if (!mounted) return;
      await _c.forward();
      if (!mounted) return;
      setState(() => _showSplash = false);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_showSplash)
          FadeTransition(
            opacity: Tween<double>(begin: 1, end: 0).animate(
              CurvedAnimation(parent: _c, curve: Curves.easeInOut),
            ),
            child: const _SplashScreen(),
          ),
      ],
    );
  }
}

class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

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
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.15),
            radius: 1.1,
            colors: [Color(0xFF161C24), Color(0xFF0C0F14)],
          ),
        ),
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
                        RepaintBoundary(child: TaijiLoader(size: 110)),
                        SizedBox(height: 30),
                        Text(
                          '玄机 · 六爻卦象',
                          style: TextStyle(
                            color: XuanTheme.textMain,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 8,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          '凝神静气 · 起卦以观其象',
                          style: TextStyle(
                            color: XuanTheme.textDim,
                            fontSize: 12.5,
                            letterSpacing: 3,
                          ),
                        ),
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
