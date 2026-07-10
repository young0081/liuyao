import 'package:flutter/material.dart';

/// 玄机安装器主题：与主应用一致的暖墨底、鎏金主强调。
class XuanTheme {
  static const Color ink = Color(0xFF10110F);
  static const Color inkDeep = Color(0xFF0B0C0A);
  static const Color inkPanel = Color(0xFF181A17);
  static const Color inkRaised = Color(0xFF22241F);
  static const Color inkSoft = Color(0xFF2A2C26);
  static const Color gold = Color(0xFFC5A45A);
  static const Color goldSoft = Color(0xFFE1CB91);
  static const Color cinnabar = Color(0xFFB85743);
  static const Color jade = Color(0xFF72A08F);
  static const Color line = Color(0xFF34362F);
  static const Color lineSoft = Color(0xFF282A25);
  static const Color textMain = Color(0xFFECE8DD);
  static const Color textMuted = Color(0xFFA9A69D);
  static const Color textDim = Color(0xFF7F8179);

  static ThemeData build() {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = base.textTheme
        .apply(bodyColor: textMain, displayColor: textMain)
        .copyWith(
          headlineSmall: const TextStyle(
            color: textMain,
            fontSize: 20,
            height: 1.25,
            fontWeight: FontWeight.w600,
          ),
          titleMedium: const TextStyle(
            color: textMain,
            fontSize: 14,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
          bodyMedium: const TextStyle(
            color: textMain,
            fontSize: 13,
            height: 1.55,
          ),
          labelLarge: const TextStyle(
            color: textMain,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        );
    return base.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: base.colorScheme.copyWith(
        primary: gold,
        secondary: cinnabar,
        surface: inkPanel,
        surfaceContainerHighest: inkRaised,
        onSurface: textMain,
        outline: line,
        error: cinnabar,
      ),
      textTheme: textTheme,
      dividerColor: lineSoft,
      dividerTheme: const DividerThemeData(color: lineSoft, thickness: 1),
      iconTheme: const IconThemeData(color: textMuted, size: 18),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: goldSoft,
        selectionColor: gold.withValues(alpha: 0.28),
        selectionHandleColor: gold,
      ),
      tooltipTheme: const TooltipThemeData(
        decoration: BoxDecoration(
          color: inkRaised,
          borderRadius: BorderRadius.all(Radius.circular(5)),
          border: Border.fromBorderSide(BorderSide(color: line)),
        ),
        textStyle: TextStyle(color: textMain, fontSize: 11.5),
        waitDuration: Duration(milliseconds: 450),
      ),
    );
  }
}

class XuanMotion {
  static const fast = Duration(milliseconds: 140);
  static const standard = Duration(milliseconds: 220);
  static const reveal = Duration(milliseconds: 420);
  static const page = Duration(milliseconds: 500);
  static const Curve ease = Cubic(0.2, 0.8, 0.2, 1);
  static const Curve emphasized = Cubic(0.16, 1, 0.3, 1);
}
