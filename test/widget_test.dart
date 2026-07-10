import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:liuyao/ui/home_page.dart';
import 'package:liuyao/ui/theme.dart';
import 'package:liuyao/ui/widgets/taiji_loader.dart';
import 'package:liuyao/domain/location_context.dart';
import 'package:liuyao/state/location_state.dart';

void main() {
  testWidgets('太极加载动画循环首尾方向连续', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: XuanTheme.build(),
        home: const Scaffold(body: Center(child: TaijiLoader(size: 64))),
      ),
    );

    double visualTurnDistance(double a, double b) {
      final delta = (a - b).abs() % 1;
      return delta > 0.5 ? 1 - delta : delta;
    }

    final loaderRotations = find.descendant(
      of: find.byType(TaijiLoader),
      matching: find.byType(RotationTransition),
    );
    List<double> turns() => tester
        .widgetList<RotationTransition>(loaderRotations)
        .map((rotation) => rotation.turns.value)
        .toList();

    await tester.pump(const Duration(milliseconds: 5199));
    final beforeLoop = turns();
    await tester.pump(const Duration(milliseconds: 1));
    final afterLoop = turns();

    expect(beforeLoop, hasLength(2));
    expect(afterLoop, hasLength(2));
    expect(visualTurnDistance(beforeLoop[0], afterLoop[0]), lessThan(0.001));
    expect(visualTurnDistance(beforeLoop[1], afterLoop[1]), lessThan(0.001));
    expect(tester.takeException(), isNull);
  });

  testWidgets('移动布局：主界面显示三个页签且首屏为起卦', (WidgetTester tester) async {
    // 模拟窄屏（移动端）。
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: HomePage())),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // 三个页签均在场。
      expect(find.text('起卦'), findsWidgets);
      expect(find.text('排盘'), findsOneWidget);
      expect(find.text('断卦'), findsOneWidget);
      expect(find.text('位置与时事参照'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('移动布局：手排完成后自动切换到排盘', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: XuanTheme.build(),
          home: const ProviderScope(child: HomePage()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('手排'));
      await tester.pump(const Duration(milliseconds: 300));
      final manualButton = find.byKey(const ValueKey('manual-cast-button'));
      await tester.ensureVisible(manualButton);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(manualButton);
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('本卦'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('移动布局：位置参照已开启时控制行不溢出', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final location = LocationContext(
      latitude: 39.9042,
      longitude: 116.4074,
      accuracyMeters: 25,
      capturedAt: DateTime.now(),
      region: '北京市',
      district: '东城区',
      recentEvents: const [
        LocationEvent(
          title: '本地公共活动安排',
          sourceName: '测试来源',
          url: 'https://example.com/event',
        ),
      ],
    );
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            locationProvider.overrideWith(
              (ref) => LocationController(
                initialState: LocationState(
                  enabled: true,
                  loaded: true,
                  phase: LocationPhase.ready,
                  context: location,
                ),
                restorePreference: false,
              ),
            ),
          ],
          child: MaterialApp(theme: XuanTheme.build(), home: const HomePage()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('位置与时事参照'), findsOneWidget);
      expect(find.textContaining('1 条近期资讯'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('窄桌面：自动使用页签布局且不溢出', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: XuanTheme.build(),
          home: const ProviderScope(child: HomePage()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(TabBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
