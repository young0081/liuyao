import 'package:flutter/material.dart';
import '../install_engine.dart';
import '../theme.dart';
import '../widgets/taiji.dart';
import 'action_style.dart';

/// 第一步：欢迎 + 检测已安装版本 + 显示本次动作。
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    super.key,
    required this.detecting,
    required this.action,
    required this.installed,
    required this.version,
    required this.tagline,
    required this.onNext,
  });

  final bool detecting;
  final InstallAction action;
  final InstalledInfo? installed;
  final String version;
  final String tagline;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final style = ActionStyle.of(action);
    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 0, 48, 28),
      child: Row(
        children: [
          // 左：视觉符号。
          Expanded(
            flex: 4,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const TaijiMark(size: 126),
                  const SizedBox(height: 24),
                  const Text(
                    '玄机 · 六爻卦象',
                    style: TextStyle(
                      color: XuanTheme.textMain,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    tagline,
                    style: const TextStyle(
                      color: XuanTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 24),
          // 右：动作卡片与说明。
          Expanded(
            flex: 5,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ActionBadge(style: style, detecting: detecting),
                const SizedBox(height: 20),
                _VersionPanel(
                  detecting: detecting,
                  installed: installed,
                  targetVersion: version,
                  action: action,
                ),
                const SizedBox(height: 24),
                Text(
                  detecting
                      ? '正在检测本机是否已安装…'
                      : '本向导将引导你完成安装。安装过程无需管理员权限，'
                            '程序将安装到你的用户目录。',
                  style: const TextStyle(
                    color: XuanTheme.textMuted,
                    fontSize: 12.5,
                    height: 1.7,
                  ),
                ),
                const SizedBox(height: 22),
                GoldButton(
                  label: '下一步',
                  icon: Icons.arrow_forward_rounded,
                  color: style.color,
                  onTap: detecting ? null : onNext,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBadge extends StatelessWidget {
  const _ActionBadge({required this.style, required this.detecting});
  final ActionStyle style;
  final bool detecting;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: XuanMotion.standard,
      curve: XuanMotion.ease,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border(
          left: BorderSide(
            color: style.color.withValues(alpha: 0.85),
            width: 3,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            detecting ? Icons.radar : style.icon,
            size: 18,
            color: style.color,
          ),
          const SizedBox(width: 10),
          Text(
            detecting ? '检测中' : style.label,
            style: TextStyle(
              color: style.color,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _VersionPanel extends StatelessWidget {
  const _VersionPanel({
    required this.detecting,
    required this.installed,
    required this.targetVersion,
    required this.action,
  });
  final bool detecting;
  final InstalledInfo? installed;
  final String targetVersion;
  final InstallAction action;

  @override
  Widget build(BuildContext context) {
    if (detecting) {
      return const SizedBox(
        height: 58,
        child: Row(
          children: [
            TaijiMark(size: 26),
            SizedBox(width: 10),
            Text(
              '正在读取本机安装信息',
              style: TextStyle(color: XuanTheme.textMuted, fontSize: 12.5),
            ),
          ],
        ),
      );
    }
    if (installed == null) {
      return _chip('目标版本', 'v$targetVersion', XuanTheme.gold);
    }
    return Row(
      children: [
        _chip('当前已装', 'v${installed!.version}', XuanTheme.textDim),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Icon(Icons.arrow_right_alt, color: XuanTheme.textDim),
        ),
        _chip('本次安装', 'v$targetVersion', ActionStyle.of(action).color),
      ],
    );
  }

  Widget _chip(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: XuanTheme.textDim, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
