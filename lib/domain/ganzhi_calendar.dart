import 'five_element.dart';

/// 干支历：以公历日期推算日、月、年干支及旬空。
class GanZhiDate {
  GanZhiDate(this.date) {
    _compute();
  }

  final DateTime date;

  late final int dayGan;
  late final int dayZhi;
  late final int monthZhi; // 月建地支（依节气近似）
  late final int yearGan;
  late final int yearZhi;
  late final List<int> xunKong; // 旬空两地支 index

  void _compute() {
    // 日干支：以 2000-01-07 为甲子日锚点。
    final anchor = DateTime.utc(2000, 1, 7);
    final target = DateTime.utc(date.year, date.month, date.day);
    final diff = target.difference(anchor).inDays;
    final idx = ((diff % 60) + 60) % 60;
    dayGan = idx % 10;
    dayZhi = idx % 12;

    // 旬空：本旬起始干支起，甲子旬空戌亥……以干支序推。
    // 旬首 = idx - (dayGan)，两空亡支 = 旬首后第10、11支。
    final xunHead = ((idx - dayGan) % 60 + 60) % 60; // 甲? 起点
    final headZhi = xunHead % 12;
    xunKong = [(headZhi + 10) % 12, (headZhi + 11) % 12];

    // 月建：依近似节气入月日。
    monthZhi = _monthZhiFor(date);

    // 年干支：以 1984 为甲子年，立春(约2/4)前算上一年。
    var solarYear = date.year;
    if (date.month == 1 || (date.month == 2 && date.day < 4)) {
      solarYear -= 1;
    }
    final yIdx = ((solarYear - 1984) % 60 + 60) % 60;
    yearGan = yIdx % 10;
    yearZhi = yIdx % 12;
  }

  /// 近似节气入月首日：立春寅、惊蛰卯……
  int _monthZhiFor(DateTime d) {
    // 每个「节」的近似起始日，对应地支。
    const table = [
      [2, 4, 2], // 立春 -> 寅
      [3, 6, 3], // 惊蛰 -> 卯
      [4, 5, 4], // 清明 -> 辰
      [5, 6, 5], // 立夏 -> 巳
      [6, 6, 6], // 芒种 -> 午
      [7, 7, 7], // 小暑 -> 未
      [8, 8, 8], // 立秋 -> 申
      [9, 8, 9], // 白露 -> 酉
      [10, 8, 10], // 寒露 -> 戌
      [11, 7, 11], // 立冬 -> 亥
      [12, 7, 0], // 大雪 -> 子
      [1, 6, 1], // 小寒 -> 丑
    ];
    // 找到不晚于当前日期的最近一个节。
    int result = 1; // 默认丑
    final md = d.month * 100 + d.day;
    // 处理跨年：小寒(1月)属丑。
    for (final row in table) {
      final startMd = row[0] * 100 + row[1];
      if (row[0] == 1) {
        if (md >= startMd && md < 204) result = row[2];
      } else {
        if (md >= startMd) result = row[2];
      }
    }
    // 1月上旬小寒前仍属子（上年大雪）
    if (d.month == 1 && d.day < 6) result = 0;
    return result;
  }

  String get dayGanZhi => '${ganZh[dayGan]}${zhiZh[dayZhi]}';
  String get monthZhiName => zhiZh[monthZhi];
  String get yearGanZhi => '${ganZh[yearGan]}${zhiZh[yearZhi]}';
  String get xunKongName => '${zhiZh[xunKong[0]]}${zhiZh[xunKong[1]]}';
  WuXing get dayElement => zhiWuXing[dayZhi];
  WuXing get monthElement => zhiWuXing[monthZhi];
}
