import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liuyao_installer/install_engine.dart';
import 'package:liuyao_installer/screens/action_style.dart';
import 'package:liuyao_installer/screens/done_screen.dart';
import 'package:liuyao_installer/screens/installing_screen.dart';
import 'package:liuyao_installer/screens/location_screen.dart';
import 'package:liuyao_installer/screens/welcome_screen.dart';
import 'package:liuyao_installer/theme.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(920, 496);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: XuanTheme.build(),
        home: Scaffold(backgroundColor: XuanTheme.inkDeep, body: child),
      ),
    );
  }

  testWidgets('检测期间下一步不可用且布局不溢出', (tester) async {
    await pumpScreen(
      tester,
      WelcomeScreen(
        detecting: true,
        action: InstallAction.fresh,
        installed: null,
        version: '1.1.0',
        tagline: '京房纳甲 · 装卦排盘',
        onNext: () {},
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));

    final button = tester.widget<GoldButton>(find.byType(GoldButton));
    expect(button.onTap, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('长安装路径和更新提示不溢出', (tester) async {
    bool? shortcut;
    await pumpScreen(
      tester,
      LocationScreen(
        targetDir:
            r'C:\Users\example\AppData\Local\Programs\Xuanji Liuyao\A Very Long Existing Folder',
        desktopShortcut: true,
        action: InstallAction.update,
        onChangeDir: (_) {},
        onToggleDesktop: (value) => shortcut = value,
        onBack: () {},
        onInstall: () {},
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(find.byType(Switch));
    expect(shortcut, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('安装进度与最近日志布局稳定', (tester) async {
    await pumpScreen(
      tester,
      InstallingScreen(
        progress: 0.73,
        message: '正在写入应用文件',
        log: List.generate(8, (index) => '安装任务 ${index + 1} 已完成'),
        error: null,
        onRetry: () {},
        onQuit: () {},
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('73%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('完成页显示操作结果、版本和安装位置', (tester) async {
    const installDir =
        r'C:\Users\example\AppData\Local\Programs\Xuanji Liuyao\A Very Long Existing Folder';
    await pumpScreen(
      tester,
      DoneScreen(
        action: InstallAction.rollback,
        version: '1.1.0',
        installDir: installDir,
        onLaunchAndClose: () async {},
        onClose: () {},
      ),
    );
    await tester.pump(const Duration(milliseconds: 950));

    expect(find.text('回退完成'), findsOneWidget);
    expect(find.text('玄机 · 六爻卦象 已回退'), findsOneWidget);
    expect(find.text('v1.1.0'), findsOneWidget);
    expect(find.text(installDir), findsOneWidget);
    expect(find.text('关闭安装器'), findsOneWidget);
    expect(find.text('立即启动'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
