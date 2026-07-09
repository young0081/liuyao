import 'five_element.dart';
import 'ganzhi_calendar.dart';
import 'hexagram_names.dart';
import 'models.dart';
import 'trigram.dart';

/// 六爻卦象引擎：京房八宫纳甲体系。
class HexagramEngine {
  /// 世爻位（0..5）依「世位表」：本宫6、一世1..五世5、游魂4、归魂3。
  /// key = 变爻数模式，这里直接用 palace position 序号。
  static const Map<int, int> _shiByPosition = {
    0: 5, // 本宫: 世在上爻(index5)
    1: 0, // 一世
    2: 1, // 二世
    3: 2, // 三世
    4: 3, // 四世
    5: 4, // 五世
    6: 3, // 游魂: 世四爻(index3)
    7: 2, // 归魂: 世三爻(index2)
  };

  static const List<String> _positionLabels = [
    '本宫', '一世', '二世', '三世', '四世', '五世', '游魂', '归魂',
  ];

  /// 由六爻 bits(下->上，1阳0阴) 构造完整卦。
  Hexagram build(List<int> bits) {
    assert(bits.length == 6);
    final lower = trigramByBits(bits.sublist(0, 3));
    final upper = trigramByBits(bits.sublist(3, 6));
    final upperIdx = trigramIndex(upper);
    final lowerIdx = trigramIndex(lower);
    final name = hexagramName(upperIdx, lowerIdx);

    final palace = _locatePalace(bits);
    final palaceTrigram = trigrams[palace.palaceIndex];
    final self = palaceTrigram.element;
    final shiPos = _shiByPosition[palace.position]!;
    final yingPos = (shiPos + 3) % 6;

    // 纳甲：下三爻用内卦纳甲，上三爻用外卦纳甲。
    final yaos = <Yao>[];
    for (var i = 0; i < 6; i++) {
      final isInner = i < 3;
      final tri = isInner ? lower : upper;
      final localPos = isInner ? i : i - 3;
      final zhi = tri.zhiAt(localPos, isInner: isInner);
      final gan = tri.ganOf(isInner: isInner);
      final lq = liuQinOf(self, zhiWuXing[zhi]);
      yaos.add(Yao(
        position: i,
        yang: bits[i] == 1,
        moving: false,
        ganIndex: gan,
        zhiIndex: zhi,
        liuQin: lq,
        isShi: i == shiPos,
        isYing: i == yingPos,
      ));
    }

    final withHidden = _attachHidden(yaos, self, palace.palaceIndex);

    return Hexagram(
      name: name,
      upperIndex: upperIdx,
      lowerIndex: lowerIdx,
      palaceIndex: palace.palaceIndex,
      palaceElement: self,
      positionLabel: _positionLabels[palace.position],
      shiPos: shiPos,
      yingPos: yingPos,
      yaos: withHidden,
    );
  }

  /// 定位卦所属八宫及世位序号。遍历八宫、八变匹配 bits。
  _PalaceLoc _locatePalace(List<int> bits) {
    for (var p = 0; p < 8; p++) {
      final variants = _palaceVariants(p);
      for (var v = 0; v < variants.length; v++) {
        if (_sameBits(variants[v], bits)) {
          return _PalaceLoc(p, v);
        }
      }
    }
    // 理论上不会到这里。
    return const _PalaceLoc(0, 0);
  }

  /// 生成某宫的八个卦 bits（本宫..归魂）。
  List<List<int>> _palaceVariants(int palaceIndex) {
    final base = List<int>.from(
      [...trigrams[palaceIndex].bits, ...trigrams[palaceIndex].bits],
    );
    final result = <List<int>>[List<int>.from(base)]; // 本宫
    final cur = List<int>.from(base);
    // 一世..五世：依次翻初、二、三、四、五爻。
    for (var line = 0; line < 5; line++) {
      cur[line] = cur[line] ^ 1;
      result.add(List<int>.from(cur));
    }
    // 游魂：由五世翻回第四爻(index3)。
    final youhun = List<int>.from(result[5]);
    youhun[3] = youhun[3] ^ 1;
    result.add(youhun);
    // 归魂：由游魂将下卦恢复为本宫下卦。
    final guihun = List<int>.from(youhun);
    for (var i = 0; i < 3; i++) {
      guihun[i] = trigrams[palaceIndex].bits[i];
    }
    result.add(guihun);
    return result;
  }

  bool _sameBits(List<int> a, List<int> b) {
    for (var i = 0; i < 6; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// 伏神：卦中缺失的六亲，从本宫首卦（纯卦）同爻位补出。
  List<Yao> _attachHidden(List<Yao> yaos, WuXing self, int palaceIndex) {
    final present = yaos.map((y) => y.liuQin).toSet();
    final missing =
        LiuQin.values.where((q) => !present.contains(q)).toList();
    if (missing.isEmpty) return yaos;

    // 本宫纯卦六爻纳甲。
    final pureBits = [...trigrams[palaceIndex].bits, ...trigrams[palaceIndex].bits];
    final pureLower = trigramByBits(pureBits.sublist(0, 3));
    final pureUpper = trigramByBits(pureBits.sublist(3, 6));
    final pureYaos = <_PureYao>[];
    for (var i = 0; i < 6; i++) {
      final isInner = i < 3;
      final tri = isInner ? pureLower : pureUpper;
      final localPos = isInner ? i : i - 3;
      final zhi = tri.zhiAt(localPos, isInner: isInner);
      final gan = tri.ganOf(isInner: isInner);
      final lq = liuQinOf(self, zhiWuXing[zhi]);
      pureYaos.add(_PureYao(lq, gan, zhi));
    }

    final result = List<Yao>.from(yaos);
    for (final q in missing) {
      // 找到本宫卦中该六亲所在爻位，伏于同爻位下。
      final idx = pureYaos.indexWhere((e) => e.liuQin == q);
      if (idx < 0) continue;
      final source = pureYaos[idx];
      result[idx] = result[idx].copyWith(
        hidden: HiddenSpirit(
          liuQin: q,
          ganIndex: source.gan,
          zhiIndex: source.zhi,
        ),
      );
    }
    return result;
  }

  /// 依日干安六神：起爻顺序 初->上。
  /// 甲乙起青龙、丙丁朱雀、戊勾陈、己螣蛇、庚辛白虎、壬癸玄武。
  List<Yao> assignLiuShen(List<Yao> yaos, int dayGan) {
    final start = _liuShenStart(dayGan);
    final order = [
      LiuShen.qinglong,
      LiuShen.zhuque,
      LiuShen.gouchen,
      LiuShen.tengshe,
      LiuShen.baihu,
      LiuShen.xuanwu,
    ];
    final result = <Yao>[];
    for (var i = 0; i < 6; i++) {
      final shen = order[(start + i) % 6];
      result.add(yaos[i].copyWith(liuShen: shen));
    }
    return result;
  }

  int _liuShenStart(int dayGan) {
    switch (dayGan) {
      case 0:
      case 1:
        return 0; // 甲乙 -> 青龙
      case 2:
      case 3:
        return 1; // 丙丁 -> 朱雀
      case 4:
        return 2; // 戊 -> 勾陈
      case 5:
        return 3; // 己 -> 螣蛇
      case 6:
      case 7:
        return 4; // 庚辛 -> 白虎
      default:
        return 5; // 壬癸 -> 玄武
    }
  }
}

class _PalaceLoc {
  const _PalaceLoc(this.palaceIndex, this.position);
  final int palaceIndex;
  final int position; // 0本宫..7归魂
}

class _PureYao {
  const _PureYao(this.liuQin, this.gan, this.zhi);
  final LiuQin liuQin;
  final int gan;
  final int zhi;
}

/// 便捷函数：合成用于展示的读卦所需的日历。
GanZhiDate ganZhiFor(DateTime date) => GanZhiDate(date);
