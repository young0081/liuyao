import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'ui/home_page.dart';
import 'ui/platform.dart';
import 'ui/splash_page.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 桌面端使用无边框自定义窗口；移动端直接进入。
  if (isDesktopPlatform) {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      size: Size(1180, 780),
      minimumSize: Size(940, 640),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden, // 无边框：隐藏系统标题栏
      windowButtonVisibility: false,
      title: '玄机 · 六爻卦象',
    );
    windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.setAsFrameless();
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const ProviderScope(child: XuanApp()));
}

class XuanApp extends StatelessWidget {
  const XuanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '玄机 · 六爻卦象',
      debugShowCheckedModeBanner: false,
      theme: XuanTheme.build(),
      home: const SplashGate(child: HomePage()),
    );
  }
}
