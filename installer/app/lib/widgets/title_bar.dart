import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../theme.dart';
import 'taiji.dart';

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
      child: Container(
        height: 50,
        decoration: const BoxDecoration(
          color: XuanTheme.inkPanel,
          border: Border(bottom: BorderSide(color: XuanTheme.lineSoft)),
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            Container(
              width: 28,
              height: 28,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: XuanTheme.inkRaised,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: XuanTheme.line),
              ),
              child: const TaijiMark(size: 22, spinning: false),
            ),
            const SizedBox(width: 9),
            const Text(
              '玄机 · 六爻卦象',
              style: TextStyle(
                color: XuanTheme.textMain,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '安装向导',
              style: TextStyle(color: XuanTheme.textDim, fontSize: 11),
            ),
            const Spacer(),
            _WindowButton(
              tooltip: '最小化',
              icon: Icons.remove,
              onTap: () => windowManager.minimize(),
            ),
            _WindowButton(
              tooltip: '关闭',
              icon: Icons.close,
              hoverColor: Color(0xFF9F4434),
              onTap: () async {
                if (onCloseGuard != null) {
                  final ok = await onCloseGuard!();
                  if (!ok) return;
                }
                await windowManager.close();
              },
            ),
            const SizedBox(width: 5),
          ],
        ),
      ),
    );
  }
}

class _WindowButton extends StatefulWidget {
  const _WindowButton({
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
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed ? 0.92 : 1,
            duration: XuanMotion.fast,
            curve: XuanMotion.ease,
            child: AnimatedContainer(
              duration: XuanMotion.fast,
              curve: XuanMotion.ease,
              width: 40,
              height: 36,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: _hover ? widget.hoverColor : Colors.transparent,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Icon(
                widget.icon,
                size: 16,
                color: _hover ? XuanTheme.textMain : XuanTheme.textDim,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
