import 'package:flutter/material.dart';
import '../install_engine.dart';
import '../theme.dart';

/// 安装动作对应的中文标签与配色。
class ActionStyle {
  const ActionStyle(this.label, this.verb, this.color, this.icon);
  final String label; // 全新安装 / 更新 / 回退 / 重新安装
  final String verb; // 按钮动词
  final Color color;
  final IconData icon;

  static ActionStyle of(InstallAction a) {
    switch (a) {
      case InstallAction.fresh:
        return const ActionStyle(
          '全新安装',
          '开始安装',
          XuanTheme.gold,
          Icons.auto_awesome,
        );
      case InstallAction.update:
        return const ActionStyle(
          '发现新版本',
          '更新到此版本',
          XuanTheme.jade,
          Icons.upgrade,
        );
      case InstallAction.rollback:
        return const ActionStyle(
          '版本回退',
          '回退到此版本',
          XuanTheme.cinnabar,
          Icons.history,
        );
      case InstallAction.reinstall:
        return const ActionStyle(
          '重新安装',
          '修复安装',
          XuanTheme.goldSoft,
          Icons.build_circle_outlined,
        );
    }
  }
}

/// 鎏金主行动按钮。
class GoldButton extends StatefulWidget {
  const GoldButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.color = XuanTheme.gold,
    this.filled = true,
  });
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color color;
  final bool filled;

  @override
  State<GoldButton> createState() => _GoldButtonState();
}

class _GoldButtonState extends State<GoldButton> {
  bool _hover = false;
  bool _pressed = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final fg = enabled
        ? (widget.filled ? XuanTheme.ink : widget.color)
        : XuanTheme.textDim;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        onHover: (value) => setState(() => _hover = value),
        onHighlightChanged: (value) => setState(() => _pressed = value),
        onFocusChange: (value) => setState(() => _focused = value),
        borderRadius: BorderRadius.circular(6),
        mouseCursor: enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1,
          duration: XuanMotion.fast,
          curve: XuanMotion.ease,
          child: AnimatedContainer(
            duration: XuanMotion.standard,
            curve: XuanMotion.ease,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            decoration: BoxDecoration(
              color: !enabled
                  ? XuanTheme.lineSoft
                  : widget.filled
                  ? (_hover
                        ? widget.color
                        : widget.color.withValues(alpha: 0.9))
                  : (_hover
                        ? widget.color.withValues(alpha: 0.12)
                        : Colors.transparent),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _focused
                    ? XuanTheme.textMain
                    : enabled
                    ? widget.color.withValues(alpha: widget.filled ? 0.5 : 0.6)
                    : XuanTheme.line,
                width: _focused ? 1.8 : 1,
              ),
              boxShadow: enabled && widget.filled && _hover
                  ? [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.22),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 17, color: fg),
                  const SizedBox(width: 8),
                ],
                Text(
                  widget.label,
                  style: TextStyle(
                    color: fg,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
