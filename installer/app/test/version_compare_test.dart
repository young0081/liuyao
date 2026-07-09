import 'package:flutter_test/flutter_test.dart';
import 'package:liuyao_installer/install_engine.dart';

void main() {
  group('版本比较', () {
    test('高版本大于低版本', () {
      expect(InstallEngine.compareVersions('1.0.1', '1.0.0'), 1);
      expect(InstallEngine.compareVersions('1.1.0', '1.0.9'), 1);
      expect(InstallEngine.compareVersions('2.0.0', '1.9.9'), 1);
    });

    test('数字段按数值比较而非字典序', () {
      expect(InstallEngine.compareVersions('1.0.10', '1.0.9'), 1);
    });

    test('相等返回 0，忽略构建号分隔符', () {
      expect(InstallEngine.compareVersions('1.0.1', '1.0.1'), 0);
      expect(InstallEngine.compareVersions('1.0.1+2', '1.0.1'), 0);
    });

    test('低版本小于高版本', () {
      expect(InstallEngine.compareVersions('1.0.0', '1.0.1'), -1);
    });
  });

  group('安装动作判定', () {
    final engine = InstallEngine(
      appName: 'X',
      appExe: 'liuyao.exe',
      appVersion: '1.0.1',
      publisher: 'p',
      regKey: r'Software\XuanjiLiuyao',
      appId: '{GUID}',
    );

    test('无已装为全新安装', () {
      expect(engine.actionFor(null), InstallAction.fresh);
    });

    test('目标高于已装为更新', () {
      expect(
        engine.actionFor(const InstalledInfo(version: '1.0.0', path: 'C:\\x')),
        InstallAction.update,
      );
    });

    test('目标低于已装为回退', () {
      expect(
        engine.actionFor(const InstalledInfo(version: '1.0.2', path: 'C:\\x')),
        InstallAction.rollback,
      );
    });

    test('版本相同为重新安装', () {
      expect(
        engine.actionFor(const InstalledInfo(version: '1.0.1', path: 'C:\\x')),
        InstallAction.reinstall,
      );
    });
  });
}
