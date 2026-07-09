import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 玄机主题：深墨底、鎏金点缀、朱砂高亮。
class XuanTheme {
  static const Color ink = Color(0xFF0E1116); // 墨底
  static const Color inkPanel = Color(0xFF161B22); // 面板
  static const Color inkRaised = Color(0xFF1E252E); // 卡片
  static const Color gold = Color(0xFFC7A24B); // 鎏金
  static const Color goldSoft = Color(0xFFD9BE7E);
  static const Color cinnabar = Color(0xFFB4402E); // 朱砂
  static const Color jade = Color(0xFF4C8C7E); // 青
  static const Color line = Color(0xFF2A313B);
  static const Color textMain = Color(0xFFE7E2D4);
  static const Color textDim = Color(0xFF8B93A0);

  // 五行配色。
  static const Map<String, Color> elementColors = {
    '金': Color(0xFFD9BE7E),
    '木': Color(0xFF6FB48A),
    '水': Color(0xFF5B8FD1),
    '火': Color(0xFFCB5C4A),
    '土': Color(0xFFBE955A),
  };

  static ThemeData build() {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = GoogleFonts.notoSerifScTextTheme(base.textTheme).apply(
      bodyColor: textMain,
      displayColor: textMain,
    );
    return base.copyWith(
      scaffoldBackgroundColor: ink,
      colorScheme: base.colorScheme.copyWith(
        primary: gold,
        secondary: cinnabar,
        surface: inkPanel,
        onSurface: textMain,
      ),
      textTheme: textTheme,
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

Color elementColor(String zh) => XuanTheme.elementColors[zh] ?? XuanTheme.textMain;
