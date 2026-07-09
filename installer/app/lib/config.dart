/// 构建期注入的安装参数（通过 --dart-define 覆盖）。
class InstallerConfig {
  static const appName = String.fromEnvironment(
    'APP_NAME',
    defaultValue: '玄机 · 六爻卦象',
  );
  static const appExe = String.fromEnvironment(
    'APP_EXE',
    defaultValue: 'liuyao.exe',
  );
  static const appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.2',
  );
  static const publisher = String.fromEnvironment(
    'APP_PUBLISHER',
    defaultValue: 'young0081',
  );
  static const regKey = String.fromEnvironment(
    'APP_REGKEY',
    defaultValue: r'Software\XuanjiLiuyao',
  );
  static const appId = String.fromEnvironment(
    'APP_ID',
    defaultValue: '{8F2C4A6E-3B1D-4E7A-9C5F-6D2A1B3C4D5E}',
  );
  static const tagline = String.fromEnvironment(
    'APP_TAGLINE',
    defaultValue: '京房纳甲 · 装卦排盘',
  );
}
