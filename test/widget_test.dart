import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:liuyao/ui/home_page.dart';

void main() {
  testWidgets('移动布局：主界面显示三个页签且首屏为起卦', (WidgetTester tester) async {
    // 模拟窄屏（移动端）。
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: HomePage(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // 三个页签均在场。
      expect(find.text('起卦'), findsWidgets);
      expect(find.text('排盘'), findsOneWidget);
      expect(find.text('断卦'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
