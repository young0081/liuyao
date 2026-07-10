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
        height: 50,
        decoration: const BoxDecoration(
          color: XuanTheme.inkPanel,
          border: Border(
            bottom: BorderSide(color: XuanTheme.lineSoft, width: 1),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            const _BrandMark(size: 28),
            const SizedBox(width: 9),
            const Text(
              '玄机 · 六爻卦象',
              style: TextStyle(
                color: XuanTheme.textMain,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              '京房纳甲 · 装卦排盘',
              style: TextStyle(color: XuanTheme.textDim, fontSize: 11),
            ),
            const Spacer(),
            if (widget.showSettings)
              _WinButton(
                tooltip: 'AI 供应商配置',
                icon: Icons.settings_outlined,
                iconSize: 17,
                onTap: () => showAiSettingsDialog(context),
              ),
            const SizedBox(
              height: 18,
              child: VerticalDivider(width: 1, color: XuanTheme.line),
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
              hoverColor: Color(0xFF9F4434),
              onTap: () => windowManager.close(),
            ),
            const SizedBox(width: 4),
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
        border: Border(bottom: BorderSide(color: XuanTheme.lineSoft, width: 1)),
      ),
      child: SizedBox(
        height: 54,
        child: Row(
          children: [
            const SizedBox(width: 14),
            const _BrandMark(size: 30),
            const SizedBox(width: 9),
            const Expanded(
              child: Text(
                '玄机 · 六爻卦象',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: XuanTheme.textMain,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (widget.showSettings)
              IconButton(
                tooltip: 'AI 供应商配置',
                icon: const Icon(
                  Icons.settings_outlined,
                  size: 19,
                  color: XuanTheme.textMuted,
                ),
                onPressed: () => showAiSettingsDialog(context),
              ),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: XuanTheme.inkRaised,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: XuanTheme.line),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.asset(
          'assets/icon/app_icon.png',
          fit: BoxFit.cover,
          cacheWidth: 64,
          cacheHeight: 64,
          filterQuality: FilterQuality.medium,
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
                size: widget.iconSize,
                color: _hover ? XuanTheme.textMain : XuanTheme.textDim,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
