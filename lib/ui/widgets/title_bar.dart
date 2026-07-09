import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../theme.dart';
import '../platform.dart';
import 'ai_settings_dialog.dart';

/// 标题栏：桌面端为可拖拽 + 最小化/最大化/关闭的无边框窗口条；
/// 移动端为普通顶栏（仅品牌与设置入口，无窗口按钮、无 window_manager 调用）。
class XuanTitleBar extends StatefulWidget {
  const XuanTitleBar({super.key, this.showSettings = true});

  final bool showSettings;

  @override
  State<XuanTitleBar> createState() => _XuanTitleBarState();
}

class _XuanTitleBarState extends State<XuanTitleBar> {
  @override
  Widget build(BuildContext context) {
    if (!isDesktopPlatform) {
      return _buildMobileBar(context);
    }
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => windowManager.startDragging(),
      onDoubleTap: () async {
        if (await windowManager.isMaximized()) {
          windowManager.unmaximize();
        } else {
          windowManager.maximize();
        }
      },
      child: Container(
        height: 46,
        decoration: const BoxDecoration(
          color: XuanTheme.inkPanel,
          border: Border(
            bottom: BorderSide(color: XuanTheme.line, width: 1),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: XuanTheme.gold, width: 1.2),
              ),
              child: const Text('☯',
                  style: TextStyle(color: XuanTheme.gold, fontSize: 15)),
            ),
            const SizedBox(width: 10),
            const Text(
              '玄机 · 六爻卦象',
              style: TextStyle(
                color: XuanTheme.textMain,
                fontSize: 14,
                letterSpacing: 2,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              '京房纳甲 · 装卦排盘',
              style: TextStyle(color: XuanTheme.textDim, fontSize: 11.5),
            ),
            const Spacer(),
            if (widget.showSettings)
              _WinButton(
                tooltip: 'AI 供应商配置',
                icon: Icons.settings_outlined,
                iconSize: 17,
                onTap: () => showAiSettingsDialog(context),
              ),
            _WinButton(
              tooltip: '最小化',
              icon: Icons.remove,
              onTap: () => windowManager.minimize(),
            ),
            _WinButton(
              tooltip: '最大化',
              icon: Icons.crop_square,
              iconSize: 15,
              onTap: () async {
                if (await windowManager.isMaximized()) {
                  windowManager.unmaximize();
                } else {
                  windowManager.maximize();
                }
              },
            ),
            _WinButton(
              tooltip: '关闭',
              icon: Icons.close,
              hoverColor: XuanTheme.cinnabar,
              onTap: () => windowManager.close(),
            ),
          ],
        ),
      ),
    );
  }

  /// 移动端顶栏：品牌标识 + 设置入口，随系统状态栏留出安全区。
  Widget _buildMobileBar(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.only(top: topInset),
      decoration: const BoxDecoration(
        color: XuanTheme.inkPanel,
        border: Border(
          bottom: BorderSide(color: XuanTheme.line, width: 1),
        ),
      ),
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            const SizedBox(width: 16),
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: XuanTheme.gold, width: 1.2),
              ),
              child: const Text('☯',
                  style: TextStyle(color: XuanTheme.gold, fontSize: 16)),
            ),
            const SizedBox(width: 10),
            const Text(
              '玄机 · 六爻卦象',
              style: TextStyle(
                color: XuanTheme.textMain,
                fontSize: 15,
                letterSpacing: 2,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (widget.showSettings)
              IconButton(
                tooltip: 'AI 供应商配置',
                icon: const Icon(Icons.settings_outlined,
                    size: 20, color: XuanTheme.textDim),
                onPressed: () => showAiSettingsDialog(context),
              ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

class _WinButton extends StatefulWidget {
  const _WinButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.hoverColor = XuanTheme.inkRaised,
    this.iconSize = 18,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final Color hoverColor;
  final double iconSize;

  @override
  State<_WinButton> createState() => _WinButtonState();
}

class _WinButtonState extends State<_WinButton> {
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
          child: Container(
            width: 46,
            height: 46,
            color: _hover ? widget.hoverColor : Colors.transparent,
            child: Icon(
              widget.icon,
              size: widget.iconSize,
              color: _hover ? XuanTheme.textMain : XuanTheme.textDim,
            ),
          ),
        ),
      ),
    );
  }
}
