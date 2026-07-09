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
      padding: const EdgeInsets.fromLTRB(56, 12, 56, 34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepHeader(index: 2, title: '安装位置'),
          const SizedBox(height: 28),
          const Text(
            '安装目录',
            style: TextStyle(color: XuanTheme.textMain, fontSize: 13,
                letterSpacing: 2),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: XuanTheme.inkPanel.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: XuanTheme.line),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.folder_outlined,
                          size: 18, color: XuanTheme.gold),
                      const SizedBox(width: 10),
                      Expanded(
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
            Row(
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
          ],
          const SizedBox(height: 30),
          const Text(
            '选项',
            style: TextStyle(color: XuanTheme.textMain, fontSize: 13,
                letterSpacing: 2),
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

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.index, required this.title});
  final int index;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '0$index',
          style: TextStyle(
            color: XuanTheme.gold.withValues(alpha: 0.5),
            fontSize: 30,
            fontWeight: FontWeight.w300,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Text(
            title,
            style: const TextStyle(
              color: XuanTheme.textMain,
              fontSize: 18,
              letterSpacing: 4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
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
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _hover
                ? XuanTheme.gold.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: XuanTheme.gold.withValues(alpha: 0.6)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 16, color: XuanTheme.gold),
              const SizedBox(width: 8),
              Text(widget.label,
                  style: const TextStyle(
                      color: XuanTheme.gold, fontSize: 13, letterSpacing: 2)),
            ],
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
      borderRadius: BorderRadius.circular(10),
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: XuanTheme.inkPanel.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: XuanTheme.line),
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: XuanTheme.textMain, fontSize: 13)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: const TextStyle(
                        color: XuanTheme.textDim, fontSize: 11.5)),
              ],
            ),
            const Spacer(),
            _Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _Switch extends StatelessWidget {
  const _Switch({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 46,
        height: 26,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value
              ? XuanTheme.gold.withValues(alpha: 0.85)
              : XuanTheme.line,
          borderRadius: BorderRadius.circular(20),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: XuanTheme.ink,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
