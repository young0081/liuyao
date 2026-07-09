import 'package:flutter/material.dart';
import '../install_engine.dart';
import '../theme.dart';
import '../widgets/taiji.dart';
import 'action_style.dart';

/// 第四步：完成。
class DoneScreen extends StatefulWidget {
  const DoneScreen({
    super.key,
    required this.action,
    required this.version,
    required this.onLaunchAndClose,
    required this.onClose,
  });

  final InstallAction action;
  final String version;
  final Future<void> Function() onLaunchAndClose;
  final VoidCallback onClose;

  @override
  State<DoneScreen> createState() => _DoneScreenState();
}

class _DoneScreenState extends State<DoneScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = ActionStyle.of(widget.action);
    final fade = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    final done = switch (widget.action) {
      InstallAction.update => '更新完成',
      InstallAction.rollback => '回退完成',
      InstallAction.reinstall => '修复完成',
      InstallAction.fresh => '安装完成',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 8, 48, 44),
      child: Center(
        child: FadeTransition(
          opacity: fade,
          child: AnimatedBuilder(
            animation: fade,
            builder: (_, child) => Transform.translate(
              offset: Offset(0, (1 - fade.value) * 18),
              child: child,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    const TaijiMark(size: 120, spinning: false),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: style.color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: style.color.withValues(alpha: 0.5),
                            blurRadius: 22,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.check,
                          color: XuanTheme.ink, size: 26),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                Text(
                  done,
                  style: const TextStyle(
                    color: XuanTheme.textMain,
                    fontSize: 24,
                    letterSpacing: 6,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '玄机 · 六爻卦象  v${widget.version}  已就绪',
                  style: const TextStyle(
                      color: XuanTheme.textDim, fontSize: 12.5, letterSpacing: 2),
                ),
                const SizedBox(height: 34),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GoldButton(
                      label: '完成',
                      color: XuanTheme.textDim,
                      filled: false,
                      onTap: widget.onClose,
                    ),
                    const SizedBox(width: 16),
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
    );
  }
}
