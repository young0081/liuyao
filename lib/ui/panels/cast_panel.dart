import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../state/app_state.dart';
import '../../state/location_state.dart';
import '../home_page.dart';
import '../theme.dart';
import '../widgets/taiji_loader.dart';

class CastPanel extends ConsumerStatefulWidget {
  const CastPanel({super.key, required this.state});

  final DivinationState state;

  @override
  ConsumerState<CastPanel> createState() => _CastPanelState();
}

class _CastPanelState extends ConsumerState<CastPanel> {
  late final TextEditingController _questionCtrl = TextEditingController(
    text: widget.state.question,
  );

  @override
  void didUpdateWidget(covariant CastPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 由历史载入等外部来源改动了问题时，同步到输入框（避免打断用户输入）。
    if (widget.state.question != _questionCtrl.text) {
      _questionCtrl.value = TextEditingValue(
        text: widget.state.question,
        selection: TextSelection.collapsed(
          offset: widget.state.question.length,
        ),
      );
    }
  }

  @override
  void dispose() {
    _questionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final ctrl = ref.read(divinationProvider.notifier);
    final location = ref.watch(locationProvider);
    return XuanCard(
      title: '起卦',
      step: '壹',
      icon: Icons.toll_outlined,
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Label('所问之事'),
            const SizedBox(height: 6),
            TextField(
              maxLines: 2,
              style: const TextStyle(color: XuanTheme.textMain, fontSize: 13),
              onChanged: ctrl.setQuestion,
              controller: _questionCtrl,
              decoration: _fieldDecoration('心诚则灵，默念所占之事…'),
            ),
            const SizedBox(height: 16),
            const _Label('环境参照'),
            const SizedBox(height: 6),
            _LocationContextControl(
              state: location,
              onToggle: _toggleLocation,
              onRefresh: () => ref
                  .read(locationProvider.notifier)
                  .refresh(requestPermission: true),
              onOpenSettings: () {
                final controller = ref.read(locationProvider.notifier);
                if (location.needsLocationSettings) {
                  controller.openLocationSettings();
                } else {
                  controller.openAppSettings();
                }
              },
            ),
            const SizedBox(height: 16),
            const _Label('起卦方式'),
            const SizedBox(height: 6),
            _MethodToggle(method: state.method, onChanged: ctrl.setMethod),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SizeTransition(sizeFactor: anim, child: child),
              ),
              child: state.method == CastMethod.coins
                  ? _CoinCaster(
                      key: const ValueKey('coins'),
                      state: state,
                      ctrl: ctrl,
                    )
                  : _ManualCaster(
                      key: const ValueKey('manual'),
                      state: state,
                      ctrl: ctrl,
                    ),
            ),
            const SizedBox(height: 20),
            const Divider(color: XuanTheme.line, height: 1),
            const SizedBox(height: 14),
            Row(
              children: [
                const _Label('近期卦例'),
                const Spacer(),
                if (state.history.isNotEmpty)
                  Text(
                    '${state.history.length} 条',
                    style: const TextStyle(
                      color: XuanTheme.textDim,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _History(state: state, ctrl: ctrl),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleLocation(bool enabled) async {
    final controller = ref.read(locationProvider.notifier);
    if (!enabled) {
      await controller.disable();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: XuanTheme.inkPanel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: XuanTheme.line),
        ),
        title: const Row(
          children: [
            Icon(Icons.location_on_outlined, color: XuanTheme.gold, size: 19),
            SizedBox(width: 9),
            Text(
              '启用位置参照',
              style: TextStyle(color: XuanTheme.textMain, fontSize: 16),
            ),
          ],
        ),
        content: const Text(
          '应用将在起卦时读取前台位置，并用坐标获取行政区、天气和公开的近期本地资讯。'
          '位置快照会随卦例保存在本机；所问内容不会发送给地图、天气或资讯服务。',
          style: TextStyle(
            color: XuanTheme.textMuted,
            fontSize: 12.5,
            height: 1.7,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              '暂不启用',
              style: TextStyle(color: XuanTheme.textDim),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              '继续授权',
              style: TextStyle(color: XuanTheme.goldSoft),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await controller.enableAndRefresh();
    }
  }
}

class _LocationContextControl extends StatelessWidget {
  const _LocationContextControl({
    required this.state,
    required this.onToggle,
    required this.onRefresh,
    required this.onOpenSettings,
  });

  final LocationState state;
  final ValueChanged<bool> onToggle;
  final VoidCallback onRefresh;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final location = state.context;
    final status = switch (state.phase) {
      LocationPhase.disabled => '不使用位置与本地资讯',
      LocationPhase.idle => '等待获取当前位置',
      LocationPhase.requesting => '等待系统位置授权',
      LocationPhase.locating => '正在获取当前位置',
      LocationPhase.enriching => '正在检索当地资料与近期事件',
      LocationPhase.ready =>
        '${location?.placeLabel ?? '位置已取得'} · '
            '${location?.recentEvents.length ?? 0} 条近期资讯',
      LocationPhase.partial => '${location?.placeLabel ?? '位置已取得'} · 部分联网资料未取得',
      LocationPhase.error => state.error ?? '位置资料获取失败',
    };
    final statusColor = state.phase == LocationPhase.error
        ? XuanTheme.cinnabar
        : state.phase == LocationPhase.ready
        ? XuanTheme.goldSoft
        : XuanTheme.textDim;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: XuanTheme.inkRaised,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: state.enabled
              ? XuanTheme.gold.withValues(alpha: 0.42)
              : XuanTheme.lineSoft,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            height: 30,
            child: state.busy
                ? const Center(child: TaijiLoader(size: 24))
                : Icon(
                    location == null
                        ? Icons.location_searching_outlined
                        : Icons.my_location,
                    size: 18,
                    color: state.enabled ? XuanTheme.gold : XuanTheme.textDim,
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '位置与时事参照',
                  style: TextStyle(
                    color: XuanTheme.textMain,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  status,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (state.enabled && !state.busy)
            Tooltip(
              message: state.needsAppSettings || state.needsLocationSettings
                  ? '打开系统设置'
                  : '刷新位置资料',
              child: IconButton(
                onPressed: state.needsAppSettings || state.needsLocationSettings
                    ? onOpenSettings
                    : onRefresh,
                icon: Icon(
                  state.needsAppSettings || state.needsLocationSettings
                      ? Icons.settings_outlined
                      : Icons.refresh,
                  size: 17,
                ),
                color: XuanTheme.textMuted,
                visualDensity: VisualDensity.compact,
              ),
            ),
          Switch(
            value: state.enabled,
            onChanged: state.loaded && !state.busy ? onToggle : null,
            activeThumbColor: XuanTheme.ink,
            activeTrackColor: XuanTheme.gold,
            inactiveThumbColor: XuanTheme.textDim,
            inactiveTrackColor: XuanTheme.line,
            trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
          ),
        ],
      ),
    );
  }
}

class _CoinCaster extends StatelessWidget {
  const _CoinCaster({super.key, required this.state, required this.ctrl});
  final DivinationState state;
  final DivinationController ctrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: XuanTheme.inkRaised,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: XuanTheme.lineSoft),
          ),
          child: Column(
            children: [
              AnimatedSwitcher(
                duration: XuanMotion.standard,
                switchInCurve: XuanMotion.emphasized,
                switchOutCurve: Curves.easeInCubic,
                child: state.tossing
                    ? const _SpinningCoins(key: ValueKey('spin'))
                    : const _RestCoins(key: ValueKey('rest')),
              ),
              const SizedBox(height: 12),
              // 起卦过程：六爻自初爻起逐一揭示。
              _CastLadder(reveal: state.castReveal, step: state.castStep),
              const SizedBox(height: 10),
              _CastHint(state: state),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _PrimaryButton(
          key: const ValueKey('coin-cast-button'),
          label: state.preparingContext && !state.tossing
              ? '正在获取方位…'
              : state.tossing
              ? '摇卦中…'
              : '摇卦',
          icon: Icons.casino,
          onTap: state.tossing || state.preparingContext
              ? null
              : ctrl.castByCoins,
        ),
      ],
    );
  }
}

/// 起卦爻梯：自下(初爻)而上(上爻)逐一揭示，动爻以朱砂点标记。
class _CastLadder extends StatelessWidget {
  const _CastLadder({required this.reveal, required this.step});
  final List<int?> reveal;
  final int step; // 已揭示的爻数 0..6

  @override
  Widget build(BuildContext context) {
    const names = ['初', '二', '三', '四', '五', '上'];
    return Column(
      children: [
        // 由上(第5位)到下(第0位)排列，符合六爻自下而上的书写习惯。
        for (var pos = 5; pos >= 0; pos--)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  child: Text(
                    names[pos],
                    style: TextStyle(
                      color: reveal[pos] != null
                          ? XuanTheme.goldSoft
                          : XuanTheme.textDim.withValues(alpha: 0.5),
                      fontSize: 10.5,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _YaoLine(
                    value: reveal[pos],
                    active: step == pos && reveal[pos] == null,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 单条爻线：未揭示为暗淡占位，揭示后画阴/阳线并标动爻。
class _YaoLine extends StatelessWidget {
  const _YaoLine({required this.value, required this.active});
  final int? value; // 6/7/8/9 或 null
  final bool active;

  @override
  Widget build(BuildContext context) {
    final revealed = value != null;
    final yang = value == 7 || value == 9;
    final moving = value == 6 || value == 9;
    final color = revealed
        ? (moving ? XuanTheme.cinnabar : XuanTheme.goldSoft)
        : XuanTheme.line;
    Widget bar;
    if (!revealed) {
      // 占位：一整条暗线，正在摇的那爻呼吸闪动。
      bar = Container(
        height: 6,
        decoration: BoxDecoration(
          color: color.withValues(alpha: active ? 0.6 : 0.3),
          borderRadius: BorderRadius.circular(3),
        ),
      );
      if (active) bar = _Pulse(child: bar);
    } else if (yang) {
      // 阳爻：一整条。
      bar = Container(
        height: 6,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      );
    } else {
      // 阴爻：断为两段。
      bar = Row(
        children: [
          Expanded(
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      );
    }
    final line = AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SizeTransition(
          sizeFactor: anim,
          axis: Axis.horizontal,
          child: child,
        ),
      ),
      child: KeyedSubtree(key: ValueKey('${value ?? -1}-$active'), child: bar),
    );
    return Row(
      children: [
        Expanded(child: line),
        SizedBox(
          width: 20,
          child: moving
              ? const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(
                    Icons.change_circle,
                    size: 12,
                    color: XuanTheme.cinnabar,
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// 起卦状态提示文案。
class _CastHint extends StatelessWidget {
  const _CastHint({required this.state});
  final DivinationState state;

  @override
  Widget build(BuildContext context) {
    const names = ['初', '二', '三', '四', '五', '上'];
    String text;
    if (state.tossing) {
      if (state.castStep >= 6 && state.preparingContext) {
        text = '正在汇入方位与当地资料';
      } else {
        final i = state.castStep.clamp(0, 5);
        text = '第 ${i + 1} / 6 爻 · ${names[i]}爻';
      }
    } else {
      text = '三枚铜钱，六掷成卦';
    }
    return AnimatedSwitcher(
      duration: XuanMotion.standard,
      child: Text(
        text,
        key: ValueKey(text),
        style: const TextStyle(color: XuanTheme.textDim, fontSize: 11.5),
      ),
    );
  }
}

/// 轻量呼吸闪动（用于未揭示爻线的“待定”提示）。
class _Pulse extends StatefulWidget {
  const _Pulse({required this.child});
  final Widget child;
  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1).animate(_c),
      child: widget.child,
    );
  }
}

class _ManualCaster extends StatelessWidget {
  const _ManualCaster({super.key, required this.state, required this.ctrl});
  final DivinationState state;
  final DivinationController ctrl;

  static const List<int> _opts = [6, 7, 8, 9];
  static const Map<int, String> _names = {
    6: '老阴 ⨯',
    7: '少阳 —',
    8: '少阴 ⚋',
    9: '老阳 ○',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var pos = 5; pos >= 0; pos--)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 34,
                  child: Text(
                    _yaoName(pos),
                    style: const TextStyle(
                      color: XuanTheme.textDim,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final v in _opts)
                        _YaoChip(
                          label: _names[v]!,
                          selected: state.manualValues[pos] == v,
                          onTap: () => ctrl.setManualYao(pos, v),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        _PrimaryButton(
          key: const ValueKey('manual-cast-button'),
          label: state.preparingContext ? '正在获取方位…' : '排盘',
          icon: Icons.grid_on,
          onTap: state.preparingContext ? null : ctrl.castManual,
        ),
      ],
    );
  }

  String _yaoName(int pos) {
    const names = ['初', '二', '三', '四', '五', '上'];
    return '${names[pos]}爻';
  }
}

class _YaoChip extends StatelessWidget {
  const _YaoChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        child: AnimatedContainer(
          duration: XuanMotion.fast,
          curve: XuanMotion.ease,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? XuanTheme.gold.withValues(alpha: 0.16)
                : XuanTheme.inkRaised,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: selected ? XuanTheme.gold : XuanTheme.line,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? XuanTheme.goldSoft : XuanTheme.textDim,
              fontSize: 11.5,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _History extends StatelessWidget {
  const _History({required this.state, required this.ctrl});
  final DivinationState state;
  final DivinationController ctrl;

  @override
  Widget build(BuildContext context) {
    if (state.history.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Column(
          children: [
            Icon(Icons.history_toggle_off, size: 20, color: XuanTheme.textDim),
            SizedBox(height: 7),
            Text(
              '尚无卦例',
              style: TextStyle(color: XuanTheme.textDim, fontSize: 12),
            ),
          ],
        ),
      );
    }
    final fmt = DateFormat('MM-dd HH:mm');
    return Column(
      children: [
        for (var i = 0; i < state.history.length; i++)
          _HistoryTile(
            title: state.history[i].primary.name,
            subtitle: [
              fmt.format(state.history[i].date),
              if (state.history[i].locationContext != null)
                state.history[i].locationContext!.placeLabel,
              state.history[i].question,
            ].join(' · '),
            selected: state.reading?.id == state.history[i].id,
            onTap: () => ctrl.loadFromHistory(i),
          ),
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: AnimatedContainer(
            duration: XuanMotion.standard,
            curve: XuanMotion.ease,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: selected
                  ? XuanTheme.gold.withValues(alpha: 0.1)
                  : XuanTheme.inkRaised,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: selected
                    ? XuanTheme.gold.withValues(alpha: 0.55)
                    : XuanTheme.lineSoft,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 28,
                  decoration: BoxDecoration(
                    color: selected ? XuanTheme.gold : XuanTheme.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: selected
                              ? XuanTheme.goldSoft
                              : XuanTheme.textMain,
                          fontSize: 12.5,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: XuanTheme.textDim,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected ? Icons.check_circle : Icons.chevron_right,
                  size: 14,
                  color: selected ? XuanTheme.gold : XuanTheme.textDim,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MethodToggle extends StatelessWidget {
  const _MethodToggle({required this.method, required this.onChanged});
  final CastMethod method;
  final ValueChanged<CastMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: XuanTheme.inkRaised,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: XuanTheme.lineSoft),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segW = (constraints.maxWidth - 6) / 2;
          final coins = method == CastMethod.coins;
          return Stack(
            children: [
              // 滑动的鎏金高亮块。
              AnimatedAlign(
                duration: XuanMotion.standard,
                curve: XuanMotion.emphasized,
                alignment: coins ? Alignment.centerLeft : Alignment.centerRight,
                child: Container(
                  width: segW,
                  height: 30,
                  decoration: BoxDecoration(
                    color: XuanTheme.gold.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: XuanTheme.gold.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  _seg('摇卦', CastMethod.coins),
                  _seg('手排', CastMethod.manual),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _seg(String label, CastMethod m) {
    final active = method == m;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onChanged(m),
          borderRadius: BorderRadius.circular(4),
          child: Container(
            height: 30,
            alignment: Alignment.center,
            child: AnimatedDefaultTextStyle(
              duration: XuanMotion.standard,
              curve: XuanMotion.ease,
              style: TextStyle(
                color: active ? XuanTheme.goldSoft : XuanTheme.textDim,
                fontSize: 12.5,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
              child: Text(label),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatefulWidget {
  const _PrimaryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _hover = false;
  bool _pressed = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
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
          scale: _pressed ? 0.97 : 1.0,
          duration: XuanMotion.fast,
          curve: XuanMotion.ease,
          child: AnimatedContainer(
            duration: XuanMotion.standard,
            curve: XuanMotion.ease,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: enabled
                  ? (_hover ? XuanTheme.goldSoft : XuanTheme.gold)
                  : XuanTheme.line,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _focused
                    ? XuanTheme.textMain
                    : enabled
                    ? XuanTheme.goldSoft.withValues(alpha: 0.65)
                    : XuanTheme.line,
                width: _focused ? 1.8 : 1,
              ),
              boxShadow: enabled && _hover
                  ? [
                      BoxShadow(
                        color: XuanTheme.gold.withValues(alpha: 0.22),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.icon,
                  size: 16,
                  color: enabled ? XuanTheme.ink : XuanTheme.textDim,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: enabled ? XuanTheme.ink : XuanTheme.textDim,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
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

class _SpinningCoins extends StatefulWidget {
  const _SpinningCoins({super.key});
  @override
  State<_SpinningCoins> createState() => _SpinningCoinsState();
}

class _SpinningCoinsState extends State<_SpinningCoins>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 920),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (i) {
          return AnimatedBuilder(
            animation: _c,
            builder: (_, child) {
              // 只使用变换模拟翻转和轻微起伏，避免逐帧触发布局变化。
              final phase = (_c.value * 2 * math.pi) + i * 0.9;
              final bob = math.sin(phase) * 3.5;
              return Transform.translate(
                offset: Offset(0, bob),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateY(phase)
                      ..rotateZ(math.sin(phase) * 0.035),
                    child: child,
                  ),
                ),
              );
            },
            child: const _Coin(showBack: true),
          );
        }),
      ),
    );
  }
}

class _RestCoins extends StatelessWidget {
  const _RestCoins({super.key});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        3,
        (i) => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: _Coin(showBack: false),
        ),
      ),
    );
  }
}

class _Coin extends StatelessWidget {
  const _Coin({required this.showBack});
  final bool showBack;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFFD9BE7E), Color(0xFFA9843C)],
        ),
        border: Border.all(color: const Color(0xFF7A5F26), width: 1.4),
      ),
      child: Center(
        child: Container(
          width: 13,
          height: 13,
          decoration: BoxDecoration(
            color: XuanTheme.inkPanel,
            border: Border.all(color: const Color(0xFF7A5F26), width: 1),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: XuanTheme.gold,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

InputDecoration _fieldDecoration(String hint) {
  return InputDecoration(hintText: hint);
}
