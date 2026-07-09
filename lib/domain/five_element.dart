/// 五行、天干、地支 的基础枚举与生克关系。
enum WuXing { metal, wood, water, fire, earth }

extension WuXingLabel on WuXing {
  String get zh {
    switch (this) {
      case WuXing.metal:
        return '金';
      case WuXing.wood:
        return '木';
      case WuXing.water:
        return '水';
      case WuXing.fire:
        return '火';
      case WuXing.earth:
        return '土';
    }
  }

  /// 我生者：木生火、火生土、土生金、金生水、水生木。
  WuXing get generates {
    switch (this) {
      case WuXing.wood:
        return WuXing.fire;
      case WuXing.fire:
        return WuXing.earth;
      case WuXing.earth:
        return WuXing.metal;
      case WuXing.metal:
        return WuXing.water;
      case WuXing.water:
        return WuXing.wood;
    }
  }

  /// 我克者：木克土、土克水、水克火、火克金、金克木。
  WuXing get overcomes {
    switch (this) {
      case WuXing.wood:
        return WuXing.earth;
      case WuXing.earth:
        return WuXing.water;
      case WuXing.water:
        return WuXing.fire;
      case WuXing.fire:
        return WuXing.metal;
      case WuXing.metal:
        return WuXing.wood;
    }
  }
}

/// 十天干。
enum Gan { jia, yi, bing, ding, wu, ji, geng, xin, ren, gui }

const List<String> ganZh = ['甲', '乙', '丙', '丁', '戊', '己', '庚', '辛', '壬', '癸'];

const List<WuXing> ganWuXing = [
  WuXing.wood, WuXing.wood, // 甲乙木
  WuXing.fire, WuXing.fire, // 丙丁火
  WuXing.earth, WuXing.earth, // 戊己土
  WuXing.metal, WuXing.metal, // 庚辛金
  WuXing.water, WuXing.water, // 壬癸水
];

/// 十二地支。
enum Zhi {
  zi, chou, yin, mao, chen, si, wu, wei, shen, you, xu, hai,
}

const List<String> zhiZh = [
  '子', '丑', '寅', '卯', '辰', '巳', '午', '未', '申', '酉', '戌', '亥',
];

/// 地支对应五行。
const List<WuXing> zhiWuXing = [
  WuXing.water, // 子
  WuXing.earth, // 丑
  WuXing.wood, // 寅
  WuXing.wood, // 卯
  WuXing.earth, // 辰
  WuXing.fire, // 巳
  WuXing.fire, // 午
  WuXing.earth, // 未
  WuXing.metal, // 申
  WuXing.metal, // 酉
  WuXing.earth, // 戌
  WuXing.water, // 亥
];

/// 地支对应生肖，用于展示。
const List<String> zhiShengXiao = [
  '鼠', '牛', '虎', '兔', '龙', '蛇', '马', '羊', '猴', '鸡', '狗', '猪',
];
