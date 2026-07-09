import 'package:flutter_test/flutter_test.dart';
import 'package:liuyao/domain/hexagram_engine.dart';
import 'package:liuyao/domain/models.dart';

void main() {
  final engine = HexagramEngine();

  test('乾为天：本宫、世上应三、纳甲子寅辰午申戌', () {
    final h = engine.build([1, 1, 1, 1, 1, 1]);
    expect(h.name, '乾为天');
    expect(h.palaceName, '乾');
    expect(h.positionLabel, '本宫');
    expect(h.shiPos, 5);
    expect(h.yingPos, 2);
    // 内乾 子寅辰，外乾 午申戌
    final zhi = h.yaos.map((y) => y.zhiIndex).toList();
    expect(zhi, [0, 2, 4, 6, 8, 10]);
    // 六亲：乾金，子孙(水) 父母... 世爻上爻戌土为父母
    expect(h.yaos[5].liuQin, LiuQin.parent);
  });

  test('坤为地：本宫、纳甲未巳卯 丑亥酉', () {
    final h = engine.build([0, 0, 0, 0, 0, 0]);
    expect(h.name, '坤为地');
    expect(h.palaceName, '坤');
    final zhi = h.yaos.map((y) => y.zhiIndex).toList();
    // 内坤 未巳卯(逆)，外坤 丑亥酉
    expect(zhi, [7, 5, 3, 1, 11, 9]);
  });

  test('火天大有 = 乾宫归魂，世三应上', () {
    // 下乾(111) 上离(101) => bits 下->上: 1,1,1, 1,0,1
    final h = engine.build([1, 1, 1, 1, 0, 1]);
    expect(h.name, '火天大有');
    expect(h.palaceName, '乾');
    expect(h.positionLabel, '归魂');
    expect(h.shiPos, 2);
  });

  test('火地晋 = 乾宫游魂，世四', () {
    // 下坤(000) 上离(101) => 0,0,0, 1,0,1
    final h = engine.build([0, 0, 0, 1, 0, 1]);
    expect(h.name, '火地晋');
    expect(h.palaceName, '乾');
    expect(h.positionLabel, '游魂');
    expect(h.shiPos, 3);
  });

  test('天风姤 = 乾宫一世，世初', () {
    // 下巽(011) 上乾(111) => 0,1,1, 1,1,1
    final h = engine.build([0, 1, 1, 1, 1, 1]);
    expect(h.name, '天风姤');
    expect(h.palaceName, '乾');
    expect(h.positionLabel, '一世');
    expect(h.shiPos, 0);
  });

  test('伏神：天风姤缺妻财、子孙有伏', () {
    final h = engine.build([0, 1, 1, 1, 1, 1]);
    final hiddenQins = h.yaos
        .where((y) => y.hidden != null)
        .map((y) => y.hidden!.liuQin)
        .toSet();
    // 乾宫属金：妻财=木、子孙=水。姤卦六亲不全，应有伏神。
    expect(hiddenQins.isNotEmpty, true);
  });

  test('六神起例：甲日青龙在初爻', () {
    final h = engine.build([1, 1, 1, 1, 1, 1]);
    final withShen = engine.assignLiuShen(h.yaos, 0); // 甲
    expect(withShen[0].liuShen, LiuShen.qinglong);
    expect(withShen[5].liuShen, LiuShen.xuanwu);
  });
}
