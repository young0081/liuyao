import 'package:flutter_test/flutter_test.dart';
import 'package:liuyao/domain/location_context.dart';
import 'package:liuyao/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('位置快照随卦例保存并可在重启后恢复', () async {
    SharedPreferences.setMockInitialValues({});
    final context = LocationContext(
      latitude: 23.1291,
      longitude: 113.2644,
      accuracyMeters: 20,
      capturedAt: _fixedTime,
      country: '中国',
      region: '广东省',
      city: '广州市',
      district: '越秀区',
      weatherSummary: '多云，28℃',
    );
    final controller = DivinationController(() async => context);
    controller.setQuestion('近期工作是否有转机');

    await controller.castManual();
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(
      controller.state.reading?.locationContext?.placeLabel,
      '广东省 · 广州市 · 越秀区',
    );
    expect(controller.state.history, hasLength(1));
    controller.dispose();

    final restored = DivinationController();
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(restored.state.history, hasLength(1));
    expect(
      restored.state.history.single.locationContext?.weatherSummary,
      '多云，28℃',
    );
    expect(restored.state.history.single.question, '近期工作是否有转机');
    restored.dispose();
  });
}

final _fixedTime = DateTime.utc(2026, 7, 10, 3, 0);
