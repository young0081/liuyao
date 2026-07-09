import 'package:flutter/material.dart';

/// 玄机安装器主题：与主应用一致的深墨底、鎏金点缀、朱砂高亮。
class XuanTheme {
  static const Color ink = Color(0xFF0E1116);
  static const Color inkPanel = Color(0xFF161B22);
  static const Color inkRaised = Color(0xFF1E252E);
  static const Color gold = Color(0xFFC7A24B);
  static const Color goldSoft = Color(0xFFD9BE7E);
  static const Color cinnabar = Color(0xFFB4402E);
  static const Color jade = Color(0xFF4C8C7E);
  static const Color line = Color(0xFF2A313B);
  static const Color textMain = Color(0xFFE7E2D4);
  static const Color textDim = Color(0xFF8B93A0);

  // 无外网依赖，使用系统可用的宋体族，回退到默认。
  static const List<String> serifFallback = <String>[
    'Noto Serif SC',
    'Source Han Serif SC',
    'STSong',
    'SimSun',
    'serif',
  ];

  static ThemeData build() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: base.colorScheme.copyWith(
        primary: gold,
        secondary: cinnabar,
        surface: inkPanel,
        onSurface: textMain,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: textMain,
        displayColor: textMain,
        fontFamilyFallback: serifFallback,
      ),
      dividerColor: line,
      tooltipTheme: const TooltipThemeData(
        decoration: BoxDecoration(
          color: inkRaised,
          borderRadius: BorderRadius.all(Radius.circular(6)),
        ),
        textStyle: TextStyle(color: textMain, fontSize: 12),
      ),
    );
  }
}
