import 'five_element.dart';

/// 六亲。
enum LiuQin { parent, sibling, offspring, wealth, officer }

extension LiuQinLabel on LiuQin {
  String get zh {
    switch (this) {
      case LiuQin.parent:
        return '父母';
      case LiuQin.sibling:
        return '兄弟';
      case LiuQin.offspring:
        return '子孙';
      case LiuQin.wealth:
        return '妻财';
      case LiuQin.officer:
        return '官鬼';
    }
  }
}

/// 依「我」（卦宫五行）判定某地支五行的六亲。
LiuQin liuQinOf(WuXing self, WuXing target) {
  if (target == self) return LiuQin.sibling; // 比和 = 兄弟
  if (target.generates == self) return LiuQin.parent; // 生我者父母
  if (self.generates == target) return LiuQin.offspring; // 我生者子孙
  if (self.overcomes == target) return LiuQin.wealth; // 我克者妻财
  return LiuQin.officer; // 克我者官鬼
}

/// 六神。
enum LiuShen { qinglong, zhuque, gouchen, tengshe, baihu, xuanwu }

extension LiuShenLabel on LiuShen {
  String get zh {
    switch (this) {
      case LiuShen.qinglong:
        return '青龙';
      case LiuShen.zhuque:
        return '朱雀';
      case LiuShen.gouchen:
        return '勾陈';
      case LiuShen.tengshe:
        return '螣蛇';
      case LiuShen.baihu:
        return '白虎';
      case LiuShen.xuanwu:
        return '玄武';
    }
  }
}

/// 一爻的完整信息。
class Yao {
  const Yao({
    required this.position, // 0=初爻 .. 5=上爻
    required this.yang,
    required this.moving,
    required this.ganIndex,
    required this.zhiIndex,
    required this.liuQin,
    this.isShi = false,
    this.isYing = false,
    this.liuShen,
    this.hidden,
  });

  final int position;
  final bool yang;
  final bool moving; // 是否动爻
  final int ganIndex;
  final int zhiIndex;
  final LiuQin liuQin;
  final bool isShi; // 世爻
  final bool isYing; // 应爻
  final LiuShen? liuShen;
  final HiddenSpirit? hidden; // 伏神

  WuXing get element => zhiWuXing[zhiIndex];
  String get ganZhi => '${ganZh[ganIndex]}${zhiZh[zhiIndex]}';
  String get zhiName => zhiZh[zhiIndex];
  String get shengXiao => zhiShengXiao[zhiIndex];

  Yao copyWith({
    bool? moving,
    bool? isShi,
    bool? isYing,
    LiuShen? liuShen,
    HiddenSpirit? hidden,
  }) {
    return Yao(
      position: position,
      yang: yang,
      moving: moving ?? this.moving,
      ganIndex: ganIndex,
      zhiIndex: zhiIndex,
      liuQin: liuQin,
      isShi: isShi ?? this.isShi,
      isYing: isYing ?? this.isYing,
      liuShen: liuShen ?? this.liuShen,
      hidden: hidden ?? this.hidden,
    );
  }
}

/// 伏神：卦中缺失六亲，从本宫卦对应爻位取出。
class HiddenSpirit {
  const HiddenSpirit({
    required this.liuQin,
    required this.ganIndex,
    required this.zhiIndex,
  });

  final LiuQin liuQin;
  final int ganIndex;
  final int zhiIndex;

  WuXing get element => zhiWuXing[zhiIndex];
  String get ganZhi => '${ganZh[ganIndex]}${zhiZh[zhiIndex]}';
}

/// 一个完整卦（含六爻、宫、世应、卦名）。
class Hexagram {
  const Hexagram({
    required this.name,
    required this.upperIndex,
    required this.lowerIndex,
    required this.palaceIndex,
    required this.palaceElement,
    required this.positionLabel, // 本宫/一世.../游魂/归魂
    required this.shiPos,
    required this.yingPos,
    required this.yaos,
  });

  final String name;
  final int upperIndex;
  final int lowerIndex;
  final int palaceIndex; // 本宫经卦 index
  final WuXing palaceElement;
  final String positionLabel;
  final int shiPos; // 世爻位 0..5
  final int yingPos;
  final List<Yao> yaos; // 0=初 .. 5=上

  String get palaceName => _palaceZh[palaceIndex];
  String get fullTitle => '$palaceName宫 · $name（$positionLabel）';
}

const List<String> _palaceZh = ['乾', '兑', '离', '震', '巽', '坎', '艮', '坤'];
