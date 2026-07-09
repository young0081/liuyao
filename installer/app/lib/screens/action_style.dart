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
            '全新安装', '开始安装', XuanTheme.gold, Icons.auto_awesome);
      case InstallAction.update:
        return const ActionStyle(
            '发现新版本', '更新到此版本', XuanTheme.jade, Icons.upgrade);
      case InstallAction.rollback:
        return const ActionStyle(
            '版本回退', '回退到此版本', XuanTheme.cinnabar, Icons.history);
      case InstallAction.reinstall:
        return const ActionStyle(
            '重新安装', '修复安装', XuanTheme.goldSoft, Icons.build_circle_outlined);
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
  final VoidCallback onTap;
  final IconData? icon;
  final Color color;
  final bool filled;

  @override
  State<GoldButton> createState() => _GoldButtonState();
}

class _GoldButtonState extends State<GoldButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final fg = widget.filled ? XuanTheme.ink : widget.color;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 13),
          decoration: BoxDecoration(
            color: widget.filled
                ? (_hover ? widget.color : widget.color.withValues(alpha: 0.88))
                : (_hover
                    ? widget.color.withValues(alpha: 0.12)
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.color.withValues(alpha: widget.filled ? 0 : 0.6),
            ),
            boxShadow: widget.filled && _hover
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 18, color: fg),
                const SizedBox(width: 8),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  color: fg,
                  fontSize: 14,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
