import 'dart:math';

import 'ganzhi_calendar.dart';
import 'hexagram_engine.dart';
import 'location_context.dart';
import 'models.dart';

/// 单爻投掷结果。三枚铜钱：字(阴)记2、背(阳)记3，合计：
/// 6 老阴(动)、7 少阳(静)、8 少阴(静)、9 老阳(动)。
class CoinToss {
  const CoinToss(this.value, this.coins);
  final int value; // 6/7/8/9
  final List<bool> coins; // true=背(阳面,记3)

  bool get yang => value == 7 || value == 9;
  bool get moving => value == 6 || value == 9;

  String get label {
    switch (value) {
      case 6:
        return '老阴';
      case 7:
        return '少阳';
      case 8:
        return '少阴';
      default:
        return '老阳';
    }
  }
}

/// 一次完整占卜的输入与产物。
class Reading {
  const Reading({
    required this.question,
    required this.date,
    required this.ganZhi,
    required this.tosses,
    required this.primary,
    required this.changed,
    required this.method,
    this.locationContext,
  });

  final String question;
  final DateTime date;
  final GanZhiDate ganZhi;
  final List<CoinToss> tosses; // 0=初 .. 5=上
  final Hexagram primary; // 本卦（含六神、伏神、世应）
  final Hexagram? changed; // 变卦（无动爻则 null）
  final String method;
  final LocationContext? locationContext;

  bool get hasMoving => tosses.any((t) => t.moving);
  List<int> get movingPositions => [
    for (var i = 0; i < 6; i++)
      if (tosses[i].moving) i,
  ];

  /// 六爻的掷值(6/7/8/9)，用于持久化后重建。
  List<int> get tossValues => tosses.map((t) => t.value).toList();

  /// 稳定标识：以起卦时刻的微秒时间戳。
  String get id => date.microsecondsSinceEpoch.toString();
}

/// 起卦器。
class Caster {
  Caster([Random? rng]) : _rng = rng ?? Random.secure();
  final Random _rng;
  final HexagramEngine _engine = HexagramEngine();

  /// 三钱摇卦：随机六爻。
  List<CoinToss> tossThreeCoins() {
    return List.generate(6, (_) {
      final coins = List.generate(3, (_) => _rng.nextBool());
      final sum = coins.fold<int>(0, (a, b) => a + (b ? 3 : 2));
      return CoinToss(sum, coins);
    });
  }

  /// 由手动指定的爻(value 6/7/8/9)构造。
  List<CoinToss> fromValues(List<int> values) {
    return values.map((v) => CoinToss(v, _coinsForValue(v))).toList();
  }

  List<bool> _coinsForValue(int v) {
    switch (v) {
      case 6:
        return [false, false, false];
      case 7:
        return [true, false, false];
      case 8:
        return [true, true, false];
      default:
        return [true, true, true];
    }
  }

  Reading castFromTosses({
    required List<CoinToss> tosses,
    required String question,
    required String method,
    DateTime? at,
    LocationContext? locationContext,
  }) {
    final date = at ?? DateTime.now();
    final gz = GanZhiDate(date);

    final primaryBits = tosses.map((t) => t.yang ? 1 : 0).toList();
    var primary = _engine.build(primaryBits);
    // 标记动爻。
    final markedYaos = [
      for (var i = 0; i < 6; i++)
        primary.yaos[i].copyWith(moving: tosses[i].moving),
    ];
    final withShen = _engine.assignLiuShen(markedYaos, gz.dayGan);
    primary = Hexagram(
      name: primary.name,
      upperIndex: primary.upperIndex,
      lowerIndex: primary.lowerIndex,
      palaceIndex: primary.palaceIndex,
      palaceElement: primary.palaceElement,
      positionLabel: primary.positionLabel,
      shiPos: primary.shiPos,
      yingPos: primary.yingPos,
      yaos: withShen,
    );

    Hexagram? changed;
    if (tosses.any((t) => t.moving)) {
      final changedBits = [
        for (var i = 0; i < 6; i++)
          tosses[i].moving
              ? (tosses[i].yang ? 0 : 1) // 老阳->阴, 老阴->阳
              : (tosses[i].yang ? 1 : 0),
      ];
      var ch = _engine.build(changedBits);
      final chShen = _engine.assignLiuShen(ch.yaos, gz.dayGan);
      changed = Hexagram(
        name: ch.name,
        upperIndex: ch.upperIndex,
        lowerIndex: ch.lowerIndex,
        palaceIndex: ch.palaceIndex,
        palaceElement: ch.palaceElement,
        positionLabel: ch.positionLabel,
        shiPos: ch.shiPos,
        yingPos: ch.yingPos,
        yaos: chShen,
      );
    }

    return Reading(
      question: question,
      date: date,
      ganZhi: gz,
      tosses: tosses,
      primary: primary,
      changed: changed,
      method: method,
      locationContext: locationContext,
    );
  }
}
