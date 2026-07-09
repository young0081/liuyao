import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../state/app_state.dart';
import '../home_page.dart';
import '../theme.dart';

class CastPanel extends ConsumerStatefulWidget {
  const CastPanel({super.key, required this.state});

  final DivinationState state;

  @override
  ConsumerState<CastPanel> createState() => _CastPanelState();
}

class _CastPanelState extends ConsumerState<CastPanel> {
  late final TextEditingController _questionCtrl =
      TextEditingController(text: widget.state.question);

  @override
  void didUpdateWidget(covariant CastPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 由历史载入等外部来源改动了问题时，同步到输入框（避免打断用户输入）。
    if (widget.state.question != _questionCtrl.text) {
      _questionCtrl.value = TextEditingValue(
        text: widget.state.question,
        selection:
            TextSelection.collapsed(offset: widget.state.question.length),
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
    return XuanCard(
      title: '起卦',
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
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
            const _Label('起卦方式'),
            const SizedBox(height: 6),
            _MethodToggle(
              method: state.method,
              onChanged: ctrl.setMethod,
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SizeTransition(
                  sizeFactor: anim,
                  child: child,
                ),
              ),
              child: state.method == CastMethod.coins
                  ? _CoinCaster(
                      key: const ValueKey('coins'), state: state, ctrl: ctrl)
                  : _ManualCaster(
                      key: const ValueKey('manual'), state: state, ctrl: ctrl),
            ),
            const SizedBox(height: 20),
            const Divider(color: XuanTheme.line, height: 1),
            const SizedBox(height: 14),
            Row(
              children: [
                const _Label('近期卦例'),
                const Spacer(),
                if (state.history.isNotEmpty)
                  Text('${state.history.length} 条',
                      style: const TextStyle(
                          color: XuanTheme.textDim, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 8),
            _History(state: state, ctrl: ctrl),
          ],
        ),
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
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: XuanTheme.line),
          ),
          child: Column(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
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
          label: state.tossing ? '摇卦中…' : '摇 卦',
          icon: Icons.casino,
          onTap: state.tossing ? null : ctrl.castByCoins,
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
                  color: color, borderRadius: BorderRadius.circular(3)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(3)),
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
            sizeFactor: anim, axis: Axis.horizontal, child: child),
      ),
      child: KeyedSubtree(
        key: ValueKey('${value ?? -1}-$active'),
        child: bar,
      ),
    );
    return Row(
      children: [
        Expanded(child: line),
        SizedBox(
          width: 20,
          child: moving
              ? const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(Icons.change_circle,
                      size: 12, color: XuanTheme.cinnabar),
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
      final i = state.castStep.clamp(0, 5);
      text = '正在摇第 ${names[i]} 爻…';
    } else {
      text = '三枚铜钱，六掷成卦';
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
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
                        color: XuanTheme.textDim, fontSize: 12),
                  ),
                ),
                Expanded(
                  child: Wrap(
                    spacing: 6,
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
          label: '排 盘',
          icon: Icons.grid_on,
          onTap: ctrl.castManual,
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
  const _YaoChip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? XuanTheme.gold.withValues(alpha: 0.16) : XuanTheme.inkRaised,
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
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('尚无卦例',
            style: TextStyle(color: XuanTheme.textDim, fontSize: 12)),
      );
    }
    final fmt = DateFormat('MM-dd HH:mm');
    return Column(
      children: [
        for (var i = 0; i < state.history.length; i++)
          _HistoryTile(
            title: state.history[i].primary.name,
            subtitle:
                '${fmt.format(state.history[i].date)} · ${state.history[i].question}',
            onTap: () => ctrl.loadFromHistory(i),
          ),
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile(
      {required this.title, required this.subtitle, required this.onTap});
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: XuanTheme.inkRaised,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: XuanTheme.line),
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome, size: 13, color: XuanTheme.gold),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: XuanTheme.textMain, fontSize: 12.5)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: XuanTheme.textDim, fontSize: 10.5)),
                ],
              ),
            ),
          ],
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
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: XuanTheme.line),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segW = (constraints.maxWidth - 6) / 2;
          final coins = method == CastMethod.coins;
          return Stack(
            children: [
              // 滑动的鎏金高亮块。
              AnimatedAlign(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                alignment:
                    coins ? Alignment.centerLeft : Alignment.centerRight,
                child: Container(
                  width: segW,
                  height: 30,
                  decoration: BoxDecoration(
                    color: XuanTheme.gold.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                        color: XuanTheme.gold.withValues(alpha: 0.5)),
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
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(m),
        child: Container(
          height: 30,
          alignment: Alignment.center,
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 240),
            style: TextStyle(
              color: active ? XuanTheme.goldSoft : XuanTheme.textDim,
              fontSize: 12.5,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatefulWidget {
  const _PrimaryButton(
      {required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: enabled
                    ? (_hover
                        ? [XuanTheme.goldSoft, XuanTheme.gold]
                        : [XuanTheme.gold, const Color(0xFFB0893A)])
                    : [XuanTheme.line, XuanTheme.line],
              ),
              borderRadius: BorderRadius.circular(7),
              boxShadow: enabled && _hover
                  ? [
                      BoxShadow(
                        color: XuanTheme.gold.withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon,
                  size: 16,
                  color: enabled ? XuanTheme.ink : XuanTheme.textDim),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  color: enabled ? XuanTheme.ink : XuanTheme.textDim,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3,
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
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 500))
        ..repeat();

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
              // 平滑的翻转：以余弦驱动 X 轴缩放，模拟铜钱旋转。
              final phase = (_c.value * 2 * math.pi) + i * 0.9;
              final scaleX = math.cos(phase).abs().clamp(0.12, 1.0);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..scaleByDouble(scaleX, 1.0, 1.0, 1.0),
                  child: child,
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
        letterSpacing: 2,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

InputDecoration _fieldDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: XuanTheme.textDim, fontSize: 12.5),
    filled: true,
    fillColor: XuanTheme.inkRaised,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(7),
      borderSide: const BorderSide(color: XuanTheme.line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(7),
      borderSide: const BorderSide(color: XuanTheme.gold),
    ),
  );
}
