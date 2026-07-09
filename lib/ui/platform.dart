import 'package:flutter/foundation.dart';

/// 平台判断助手：区分桌面（含无边框窗口）与移动端。
///
/// 通过 [defaultTargetPlatform] 判断，Web 一律按移动端布局处理。
bool get isDesktopPlatform {
  if (kIsWeb) return false;
  switch (defaultTargetPlatform) {
    case TargetPlatform.windows:
    case TargetPlatform.linux:
    case TargetPlatform.macOS:
      return true;
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.fuchsia:
      return false;
  }
}

bool get isMobilePlatform => !isDesktopPlatform;
