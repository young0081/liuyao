import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import '../install_engine.dart';
import '../theme.dart';
import 'action_style.dart';

/// 第二步：选择安装位置与快捷方式选项。
class LocationScreen extends StatelessWidget {
  const LocationScreen({
    super.key,
    required this.targetDir,
    required this.desktopShortcut,
    required this.action,
    required this.onChangeDir,
    required this.onToggleDesktop,
    required this.onBack,
    required this.onInstall,
  });

  final String targetDir;
  final bool desktopShortcut;
  final InstallAction action;
  final ValueChanged<String> onChangeDir;
  final ValueChanged<bool> onToggleDesktop;
  final VoidCallback onBack;
  final VoidCallback onInstall;

  Future<void> _pick() async {
    final dir = await getDirectoryPath(
      confirmButtonText: '选择此文件夹',
      initialDirectory: targetDir,
    );
    if (dir != null && dir.isNotEmpty) {
      onChangeDir('$dir\\Xuanji Liuyao');
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = ActionStyle.of(action);
    return Padding(
      padding: const EdgeInsets.fromLTRB(56, 20, 56, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '选择安装位置',
            style: TextStyle(
              color: XuanTheme.textMain,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '确认程序目录和快捷方式选项',
            style: TextStyle(color: XuanTheme.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 24),
          const Text(
            '安装目录',
            style: TextStyle(
              color: XuanTheme.gold,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: XuanTheme.inkRaised,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: XuanTheme.lineSoft),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.folder_outlined,
                        size: 18,
                        color: XuanTheme.gold,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Tooltip(
                          message: targetDir,
                          child: Text(
                            targetDir,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: XuanTheme.textMain,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _OutlineIconButton(
                label: '浏览',
                icon: Icons.drive_folder_upload_outlined,
                onTap: _pick,
              ),
            ],
          ),
          if (action == InstallAction.update ||
              action == InstallAction.rollback ||
              action == InstallAction.reinstall) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: style.color.withValues(alpha: 0.08),
                border: Border(left: BorderSide(color: style.color, width: 3)),
              ),
              child: Row(
                children: [
                  Icon(style.icon, size: 15, color: style.color),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '已定位到现有安装目录，${style.label}将覆盖此处的文件。',
                      style: TextStyle(color: style.color, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          const Text(
            '选项',
            style: TextStyle(
              color: XuanTheme.gold,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          _ToggleRow(
            value: desktopShortcut,
            title: '创建桌面快捷方式',
            subtitle: '在桌面放置「玄机 · 六爻卦象」图标',
            onChanged: onToggleDesktop,
          ),
          const Spacer(),
          Row(
            children: [
              GoldButton(
                label: '上一步',
                icon: Icons.arrow_back,
                color: XuanTheme.textDim,
                filled: false,
                onTap: onBack,
              ),
              const Spacer(),
              GoldButton(
                label: style.verb,
                icon: style.icon,
                color: style.color,
                onTap: onInstall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OutlineIconButton extends StatefulWidget {
  const _OutlineIconButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_OutlineIconButton> createState() => _OutlineIconButtonState();
}

class _OutlineIconButtonState extends State<_OutlineIconButton> {
  bool _hover = false;
  bool _pressed = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        onHover: (value) => setState(() => _hover = value),
        onHighlightChanged: (value) => setState(() => _pressed = value),
        onFocusChange: (value) => setState(() => _focused = value),
        borderRadius: BorderRadius.circular(6),
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1,
          duration: XuanMotion.fast,
          curve: XuanMotion.ease,
          child: AnimatedContainer(
            duration: XuanMotion.fast,
            curve: XuanMotion.ease,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _hover
                  ? XuanTheme.gold.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _focused
                    ? XuanTheme.textMain
                    : XuanTheme.gold.withValues(alpha: 0.55),
                width: _focused ? 1.8 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 16, color: XuanTheme.gold),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: const TextStyle(
                    color: XuanTheme.gold,
                    fontSize: 13,
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

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.onChanged,
  });
  final bool value;
  final String title;
  final String subtitle;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: XuanTheme.inkRaised,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: XuanTheme.lineSoft),
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: XuanTheme.textMain,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: XuanTheme.textDim,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: XuanTheme.ink,
              activeTrackColor: XuanTheme.gold,
              inactiveThumbColor: XuanTheme.textDim,
              inactiveTrackColor: XuanTheme.line,
              trackOutlineColor: const WidgetStatePropertyAll(
                Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
