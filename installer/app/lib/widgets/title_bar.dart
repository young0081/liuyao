import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../theme.dart';

/// 安装器无边框标题栏：可拖拽 + 最小化 / 关闭。
class InstallerTitleBar extends StatelessWidget {
  const InstallerTitleBar({super.key, this.onCloseGuard});

  /// 关闭前守卫（安装中可拦截并提示）。返回 true 才关闭。
  final Future<bool> Function()? onCloseGuard;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => windowManager.startDragging(),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            const SizedBox(width: 20),
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: XuanTheme.gold, width: 1.2),
              ),
              child: const Text('☯',
                  style: TextStyle(color: XuanTheme.gold, fontSize: 13)),
            ),
            const SizedBox(width: 10),
            const Text(
              '玄机 · 六爻卦象',
              style: TextStyle(
                color: XuanTheme.textMain,
                fontSize: 13,
                letterSpacing: 2,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '安装向导',
              style: TextStyle(
                color: XuanTheme.textDim.withValues(alpha: 0.9),
                fontSize: 11,
                letterSpacing: 3,
              ),
            ),
            const Spacer(),
            _CapsuleButton(
              tooltip: '最小化',
              icon: Icons.remove,
              onTap: () => windowManager.minimize(),
            ),
            _CapsuleButton(
              tooltip: '关闭',
              icon: Icons.close,
              hoverColor: XuanTheme.cinnabar,
              onTap: () async {
                if (onCloseGuard != null) {
                  final ok = await onCloseGuard!();
                  if (!ok) return;
                }
                await windowManager.close();
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

class _CapsuleButton extends StatefulWidget {
  const _CapsuleButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.hoverColor = XuanTheme.inkRaised,
  });
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final Color hoverColor;

  @override
  State<_CapsuleButton> createState() => _CapsuleButtonState();
}

class _CapsuleButtonState extends State<_CapsuleButton> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 38,
            height: 30,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: _hover ? widget.hoverColor : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              widget.icon,
              size: 16,
              color: _hover ? XuanTheme.textMain : XuanTheme.textDim,
            ),
          ),
        ),
      ),
    );
  }
}
