import 'casting.dart';
import 'five_element.dart';
import 'models.dart';

/// 依卦象生成结构化的解读要点（非宿命论，仅作参考提示）。
class Interpretation {
  const Interpretation({
    required this.summary,
    required this.points,
    required this.shiYingNote,
    required this.movingNotes,
    required this.kongWang,
  });

  final String summary;
  final List<String> points;
  final String shiYingNote;
  final List<String> movingNotes;
  final List<String> kongWang;
}

class Interpreter {
  Interpretation interpret(Reading r) {
    final h = r.primary;
    final shi = h.yaos[h.shiPos];
    final ying = h.yaos[h.yingPos];

    final points = <String>[];
    points.add('本卦「${h.name}」属${h.palaceName}宫${h.positionLabel}，'
        '宫五行为${h.palaceElement.zh}。');
    if (r.changed != null) {
      points.add('动而生变，变卦为「${r.changed!.name}」，'
          '事有转折，宜看动爻去向。');
    } else {
      points.add('六爻安静，无动爻，事态相对稳定，以世应与用神旺衰断之。');
    }

    // 世应关系。
    final rel = _relation(shi.element, ying.element);
    final shiYingNote = '世爻在${_ordinal(h.shiPos)}（${shi.liuQin.zh}·${shi.ganZhi}），'
        '应爻在${_ordinal(h.yingPos)}（${ying.liuQin.zh}·${ying.ganZhi}）。$rel';

    // 空亡。
    final kong = <String>[];
    for (final y in h.yaos) {
      if (r.ganZhi.xunKong.contains(y.zhiIndex)) {
        kong.add('${_ordinal(y.position)}${y.liuQin.zh}·${y.zhiName}（旬空）');
      }
    }

    // 动爻说明。
    final moving = <String>[];
    for (final pos in r.movingPositions) {
      final y = h.yaos[pos];
      final to = r.changed?.yaos[pos];
      final trans = to == null
          ? ''
          : ' 化「${to.liuQin.zh}·${to.ganZhi}」（${_transRelation(y.element, to.element)}）';
      moving.add('${_ordinal(pos)}${y.liuQin.zh}·${y.ganZhi} 发动$trans');
    }

    final summary = r.changed == null
        ? '静卦：以${h.palaceElement.zh}宫论衰旺，重世应与日月生克。'
        : '动卦：由「${h.name}」化「${r.changed!.name}」，动爻为占断关键。';

    return Interpretation(
      summary: summary,
      points: points,
      shiYingNote: shiYingNote,
      movingNotes: moving,
      kongWang: kong,
    );
  }

  String _relation(WuXing a, WuXing b) {
    if (a == b) return '世应比和，彼此立场相近，事多和顺。';
    if (a.generates == b) return '世生应，己方付出、主动趋向对方。';
    if (b.generates == a) return '应生世，对方来就我，多得助力。';
    if (a.overcomes == b) return '世克应，己方能制对方，主动可控。';
    return '应克世，对方压制己方，宜守不宜进。';
  }

  String _transRelation(WuXing from, WuXing to) {
    if (from == to) return '化比和';
    if (from.generates == to) return '化泄';
    if (to.generates == from) return '化回头生';
    if (from.overcomes == to) return '化克出';
    return '化回头克';
  }

  String _ordinal(int pos) {
    const names = ['初爻', '二爻', '三爻', '四爻', '五爻', '上爻'];
    return names[pos];
  }
}
