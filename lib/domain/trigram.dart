import 'five_element.dart';

/// 八卦（三爻经卦）。bits 自初爻(下)到上爻(上)，1 为阳、0 为阴。
class Trigram {
  const Trigram({
    required this.key,
    required this.zh,
    required this.symbol,
    required this.bits,
    required this.element,
    required this.nature,
    required this.innerGan,
    required this.innerStartZhi,
    required this.outerGan,
    required this.outerStartZhi,
    required this.yangPalace,
  });

  final String key;
  final String zh;
  final String symbol;
  final List<int> bits; // 下 -> 上
  final WuXing element;
  final String nature; // 天泽火雷风水山地
  final int innerGan; // 内卦天干 index
  final int innerStartZhi; // 内卦初爻地支 index
  final int outerGan;
  final int outerStartZhi;
  final bool yangPalace; // 阳卦地支顺行(+2)，阴卦逆行(-2)

  int get code => bits[0] | (bits[1] << 1) | (bits[2] << 2);

  /// 计算某一爻的纳甲地支 index。position 0..2 为下三爻，isInner=true 用内卦纳甲。
  int zhiAt(int position, {required bool isInner}) {
    final start = isInner ? innerStartZhi : outerStartZhi;
    final step = yangPalace ? 2 : -2;
    return ((start + step * position) % 12 + 12) % 12;
  }

  int ganOf({required bool isInner}) => isInner ? innerGan : outerGan;
}

/// 以初爻->上爻的顺序列出八卦，index 用于 64 卦命名表。
/// 顺序：乾 兑 离 震 巽 坎 艮 坤。
const List<Trigram> trigrams = [
  Trigram(
    key: 'qian', zh: '乾', symbol: '☰', bits: [1, 1, 1],
    element: WuXing.metal, nature: '天',
    innerGan: 0, innerStartZhi: 0, outerGan: 8, outerStartZhi: 6, yangPalace: true,
  ),
  Trigram(
    key: 'dui', zh: '兑', symbol: '☱', bits: [1, 1, 0],
    element: WuXing.metal, nature: '泽',
    innerGan: 3, innerStartZhi: 5, outerGan: 3, outerStartZhi: 11, yangPalace: false,
  ),
  Trigram(
    key: 'li', zh: '离', symbol: '☲', bits: [1, 0, 1],
    element: WuXing.fire, nature: '火',
    innerGan: 5, innerStartZhi: 3, outerGan: 5, outerStartZhi: 9, yangPalace: false,
  ),
  Trigram(
    key: 'zhen', zh: '震', symbol: '☳', bits: [1, 0, 0],
    element: WuXing.wood, nature: '雷',
    innerGan: 6, innerStartZhi: 0, outerGan: 6, outerStartZhi: 6, yangPalace: true,
  ),
  Trigram(
    key: 'xun', zh: '巽', symbol: '☴', bits: [0, 1, 1],
    element: WuXing.wood, nature: '风',
    innerGan: 7, innerStartZhi: 1, outerGan: 7, outerStartZhi: 7, yangPalace: false,
  ),
  Trigram(
    key: 'kan', zh: '坎', symbol: '☵', bits: [0, 1, 0],
    element: WuXing.water, nature: '水',
    innerGan: 4, innerStartZhi: 2, outerGan: 4, outerStartZhi: 8, yangPalace: true,
  ),
  Trigram(
    key: 'gen', zh: '艮', symbol: '☶', bits: [0, 0, 1],
    element: WuXing.earth, nature: '山',
    innerGan: 2, innerStartZhi: 4, outerGan: 2, outerStartZhi: 10, yangPalace: true,
  ),
  Trigram(
    key: 'kun', zh: '坤', symbol: '☷', bits: [0, 0, 0],
    element: WuXing.earth, nature: '地',
    innerGan: 1, innerStartZhi: 7, outerGan: 9, outerStartZhi: 1, yangPalace: false,
  ),
];

/// 依 code(下->上 二进制) 查经卦。
Trigram trigramByBits(List<int> bits) {
  final code = bits[0] | (bits[1] << 1) | (bits[2] << 2);
  return trigrams.firstWhere((t) => t.code == code);
}

int trigramIndex(Trigram t) => trigrams.indexWhere((e) => e.key == t.key);
