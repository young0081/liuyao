import 'package:flutter/material.dart';

import '../../domain/casting.dart';
import '../../domain/five_element.dart';
import '../../domain/models.dart';
import '../home_page.dart';
import '../theme.dart';
import '../widgets/taiji_loader.dart';

class ChartPanel extends StatelessWidget {
  const ChartPanel({super.key, required this.reading});
  final Reading? reading;

  @override
  Widget build(BuildContext context) {
    return XuanCard(
      title: '排盘',
      step: '贰',
      icon: Icons.view_agenda_outlined,
      trailing: reading == null
          ? null
          : Text(
              reading!.method,
              style: const TextStyle(color: XuanTheme.textDim, fontSize: 11.5),
            ),
      padding: EdgeInsets.zero,
      child: AnimatedSwitcher(
        duration: XuanMotion.reveal,
        switchInCurve: XuanMotion.emphasized,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, anim) =>
            FadeTransition(opacity: anim, child: child),
        child: reading == null
            ? const _EmptyChart(key: ValueKey('empty-chart'))
            : FadeSlideIn(
                key: ValueKey(reading!.date.microsecondsSinceEpoch),
                child: _Chart(reading: reading!),
              ),
      ),
    );
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart({super.key});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Breathing(
              minScale: 0.985,
              minOpacity: 0.48,
              child: _EmptyHexagramGlyph(),
            ),
            const SizedBox(height: 22),
            const Text(
              '凝神静气，静候卦成',
              style: TextStyle(color: XuanTheme.textMuted, fontSize: 13.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHexagramGlyph extends StatelessWidget {
  const _EmptyHexagramGlyph();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 156,
      child: Column(
        children: [
          for (var i = 0; i < 6; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: XuanTheme.gold.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  if (i.isOdd) ...[
                    const SizedBox(width: 14),
                    Expanded(
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: XuanTheme.gold.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Chart extends StatelessWidget {
  const _Chart({required this.reading});
  final Reading reading;

  @override
  Widget build(BuildContext context) {
    final gz = reading.ganZhi;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 日辰栏。
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: XuanTheme.inkRaised,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Wrap(
              spacing: 18,
              runSpacing: 6,
              children: [
                _kv('公历', _fmtDate(reading.date)),
                _kv(
                  '干支',
                  '${gz.yearGanZhi}年 ${gz.monthZhiName}月 ${gz.dayGanZhi}日',
                ),
                _kv('旬空', gz.xunKongName),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // 卦名标题。
          Row(
            children: [
              Expanded(
                child: _HexTitle(h: reading.primary, label: '本卦'),
              ),
              if (reading.changed != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: _HexTitle(h: reading.changed!, label: '变卦'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          // 六爻表：由上爻到初爻显示。
          _YaoTable(reading: reading),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$k ',
            style: const TextStyle(color: XuanTheme.textDim, fontSize: 11.5),
          ),
          TextSpan(
            text: v,
            style: const TextStyle(
              color: XuanTheme.textMain,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _HexTitle extends StatelessWidget {
  const _HexTitle({required this.h, required this.label});
  final Hexagram h;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: XuanTheme.inkRaised,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: XuanTheme.gold.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: XuanTheme.goldSoft,
                    fontSize: 10.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  h.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: XuanTheme.textMain,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${h.palaceName}宫 · ${h.positionLabel} · ${h.palaceElement.zh}',
            style: const TextStyle(color: XuanTheme.textDim, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

class _YaoTable extends StatelessWidget {
  const _YaoTable({required this.reading});
  final Reading reading;

  @override
  Widget build(BuildContext context) {
    final hasChanged = reading.changed != null;
    final table = Column(
      children: [
        _YaoTableHeader(hasChanged: hasChanged),
        const SizedBox(height: 3),
        for (var pos = 5; pos >= 0; pos--)
          StaggeredReveal(
            // 上爻先入场：5->0 对应 index 0->5。
            index: 5 - pos,
            child: _YaoRow(
              primary: reading.primary.yaos[pos],
              changed: hasChanged ? reading.changed!.yaos[pos] : null,
              kong: reading.ganZhi.xunKong.contains(
                reading.primary.yaos[pos].zhiIndex,
              ),
            ),
          ),
      ],
    );
    // 各列固定宽度之和较大，窄屏（移动端）会挤爆并裁掉最右的旬空标记；
    // 宽度不足时改为横向滚动，保证所有列可见且不被截断。
    final minWidth = hasChanged ? 430.0 : 334.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= minWidth) return table;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: SizedBox(width: minWidth, child: table),
        );
      },
    );
  }
}

class _YaoTableHeader extends StatelessWidget {
  const _YaoTableHeader({required this.hasChanged});

  final bool hasChanged;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(color: XuanTheme.textDim, fontSize: 10.5);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(
        children: [
          const SizedBox(width: 30, child: Text('六神', style: style)),
          const SizedBox(width: 66, child: Text('伏神', style: style)),
          const SizedBox(width: 84, child: Text('六亲纳甲', style: style)),
          const Expanded(
            child: Text('爻象', textAlign: TextAlign.center, style: style),
          ),
          const SizedBox(
            width: 26,
            child: Text('世应', textAlign: TextAlign.center, style: style),
          ),
          if (hasChanged)
            const SizedBox(
              width: 96,
              child: Text('变爻', textAlign: TextAlign.center, style: style),
            ),
          const SizedBox(width: 18),
        ],
      ),
    );
  }
}

class _YaoRow extends StatelessWidget {
  const _YaoRow({
    required this.primary,
    required this.changed,
    required this.kong,
  });
  final Yao primary;
  final Yao? changed;
  final bool kong;

  @override
  Widget build(BuildContext context) {
    final ec = elementColor(primary.element.zh);
    return Container(
      constraints: const BoxConstraints(minHeight: 54),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: primary.moving
            ? XuanTheme.cinnabar.withValues(alpha: 0.08)
            : primary.isShi
            ? XuanTheme.gold.withValues(alpha: 0.07)
            : Colors.transparent,
        border: Border(
          left: BorderSide(
            color: primary.moving
                ? XuanTheme.cinnabar
                : primary.isShi
                ? XuanTheme.gold
                : Colors.transparent,
            width: 3,
          ),
          bottom: const BorderSide(color: XuanTheme.lineSoft),
        ),
      ),
      child: Row(
        children: [
          // 六神。
          SizedBox(
            width: 30,
            child: Text(
              primary.liuShen?.zh ?? '',
              style: const TextStyle(color: XuanTheme.jade, fontSize: 11.5),
            ),
          ),
          // 伏神。
          SizedBox(
            width: 66,
            child: primary.hidden == null
                ? const SizedBox.shrink()
                : Text(
                    '伏 ${primary.hidden!.liuQin.zh}${_zhiOnly(primary.hidden!.ganZhi)}',
                    style: const TextStyle(
                      color: XuanTheme.textDim,
                      fontSize: 10.5,
                    ),
                  ),
          ),
          // 六亲 + 纳甲。
          SizedBox(
            width: 84,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  primary.liuQin.zh,
                  style: const TextStyle(
                    color: XuanTheme.textMain,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${primary.ganZhi}${primary.element.zh}',
                  style: TextStyle(color: ec, fontSize: 11),
                ),
              ],
            ),
          ),
          // 爻象。
          Expanded(
            child: _YaoGlyph(yang: primary.yang, moving: primary.moving),
          ),
          // 世应标记。
          SizedBox(
            width: 26,
            child: Text(
              primary.isShi ? '世' : (primary.isYing ? '应' : ''),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: primary.isShi ? XuanTheme.gold : XuanTheme.goldSoft,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          // 变爻。
          if (changed != null)
            SizedBox(
              width: 96,
              child: primary.moving
                  ? Row(
                      children: [
                        const Icon(
                          Icons.arrow_right_alt,
                          size: 15,
                          color: XuanTheme.cinnabar,
                        ),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            '${changed!.liuQin.zh}${changed!.ganZhi}',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: elementColor(changed!.element.zh),
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Text(
                      '${changed!.liuQin.zh}${changed!.ganZhi}',
                      style: const TextStyle(
                        color: XuanTheme.textDim,
                        fontSize: 11,
                      ),
                    ),
            ),
          if (kong)
            Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                border: Border.all(color: XuanTheme.textDim),
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Text(
                '空',
                style: TextStyle(color: XuanTheme.textDim, fontSize: 9.5),
              ),
            ),
        ],
      ),
    );
  }

  String _zhiOnly(String ganzhi) =>
      ganzhi.isNotEmpty ? ganzhi.substring(ganzhi.length - 1) : '';
}

/// 爻画：阳一长横，阴两段；动爻加朱砂标记(○老阳 / ⨯老阴)。
class _YaoGlyph extends StatelessWidget {
  const _YaoGlyph({required this.yang, required this.moving});
  final bool yang;
  final bool moving;

  @override
  Widget build(BuildContext context) {
    const barColor = XuanTheme.textMain;
    Widget bar;
    if (yang) {
      bar = Container(
        height: 8,
        decoration: BoxDecoration(
          color: barColor,
          borderRadius: BorderRadius.circular(2),
        ),
      );
    } else {
      bar = Row(
        children: [
          Expanded(
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Expanded(child: bar),
          const SizedBox(width: 8),
          SizedBox(
            width: 14,
            child: moving
                ? Text(
                    yang ? '○' : '×',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: XuanTheme.cinnabar,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
