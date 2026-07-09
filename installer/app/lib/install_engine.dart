import 'dart:async';
import 'dart:io';

/// 安装动作类型：由目标版本与已装版本比较得出。
enum InstallAction { fresh, update, rollback, reinstall }

/// 已安装信息（读注册表得到）。
class InstalledInfo {
  const InstalledInfo({required this.version, required this.path});
  final String version;
  final String path;
}

/// 安装进度回调事件。
class InstallProgress {
  const InstallProgress(this.fraction, this.message);
  final double fraction; // 0..1
  final String message;
}

/// 玄机六爻安装引擎（仅 Windows）。
///
/// 载荷（payload）为与安装器 exe 同目录下的 `payload\` 文件夹，内含
/// 主应用的全部发行文件（liuyao.exe + dll + data）。
class InstallEngine {
  InstallEngine({
    required this.appName,
    required this.appExe,
    required this.appVersion,
    required this.publisher,
    required this.regKey,
    required this.appId,
  });

  final String appName; // 显示名，如 玄机 · 六爻卦象
  final String appExe; // liuyao.exe
  final String appVersion; // 1.0.1
  final String publisher; // young0081
  final String regKey; // Software\XuanjiLiuyao
  final String appId; // {GUID}

  String get _uninstallKey =>
      'Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\${appId}_is1';

  /// 安装器 exe 所在目录。
  String get _installerDir => File(Platform.resolvedExecutable).parent.path;

  /// 载荷目录。
  Directory get payloadDir => Directory('$_installerDir\\payload');

  /// 默认安装根目录：%LOCALAPPDATA%\Programs\Xuanji Liuyao
  String get defaultInstallDir {
    final base = Platform.environment['LOCALAPPDATA'] ??
        '${Platform.environment['USERPROFILE']}\\AppData\\Local';
    return '$base\\Programs\\Xuanji Liuyao';
  }

  /// 读取已安装信息：优先应用自有键，回退卸载键。
  Future<InstalledInfo?> detectInstalled() async {
    for (final root in const ['HKCU', 'HKLM']) {
      final selfPath = await _regRead('$root\\$regKey', 'InstallPath');
      if (selfPath != null && selfPath.isNotEmpty) {
        final ver = await _regRead('$root\\$regKey', 'Version') ?? '';
        return InstalledInfo(version: ver, path: selfPath);
      }
      final unPath = await _regRead('$root\\$_uninstallKey', 'InstallLocation');
      if (unPath != null && unPath.isNotEmpty) {
        final ver =
            await _regRead('$root\\$_uninstallKey', 'DisplayVersion') ?? '';
        return InstalledInfo(version: ver, path: unPath);
      }
    }
    return null;
  }

  /// 计算安装动作。
  InstallAction actionFor(InstalledInfo? installed) {
    if (installed == null) return InstallAction.fresh;
    final cmp = compareVersions(appVersion, installed.version);
    if (cmp > 0) return InstallAction.update;
    if (cmp < 0) return InstallAction.rollback;
    return InstallAction.reinstall;
  }

  /// 数字版本比较：1.0.10 > 1.0.9。
  static int compareVersions(String a, String b) {
    final pa = _parts(a);
    final pb = _parts(b);
    final n = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < n; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x > y ? 1 : -1;
    }
    return 0;
  }

  static List<int> _parts(String v) {
    // 忽略 + 之后的构建元数据（如 1.0.1+2 视同 1.0.1）。
    final core = v.split('+').first;
    return core
        .split(RegExp(r'[.\-]'))
        .map((s) => int.tryParse(s.trim()) ?? 0)
        .toList();
  }

  /// 执行安装。通过 [onProgress] 汇报进度。
  Future<void> install({
    required String targetDir,
    required bool createDesktopShortcut,
    required void Function(InstallProgress) onProgress,
  }) async {
    onProgress(const InstallProgress(0.02, '正在校验安装载荷…'));
    if (!await payloadDir.exists()) {
      throw InstallException('未找到安装载荷目录：${payloadDir.path}');
    }

    final files = await payloadDir
        .list(recursive: true, followLinks: false)
        .where((e) => e is File)
        .cast<File>()
        .toList();
    if (files.isEmpty) {
      throw InstallException('安装载荷为空。');
    }

    final target = Directory(targetDir);

    // 关闭正在运行的旧程序，避免占用文件。
    onProgress(const InstallProgress(0.06, '正在结束正在运行的旧版本…'));
    await _killRunning();

    onProgress(const InstallProgress(0.10, '正在准备目标目录…'));
    await target.create(recursive: true);

    final total = files.length;
    var done = 0;
    for (final f in files) {
      final rel = f.path.substring(payloadDir.path.length).replaceAll('/', '\\');
      final destPath = '$targetDir$rel';
      final destFile = File(destPath);
      await destFile.parent.create(recursive: true);
      // 覆盖复制；失败重试一次（可能文件仍被占用）。
      try {
        await f.copy(destPath);
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await f.copy(destPath);
      }
      done++;
      final frac = 0.12 + 0.68 * (done / total);
      onProgress(InstallProgress(
        frac,
        '正在写入文件 $done / $total',
      ));
    }

    onProgress(const InstallProgress(0.84, '正在写入注册表…'));
    await _writeRegistry(targetDir);

    onProgress(const InstallProgress(0.90, '正在生成卸载程序…'));
    await _writeUninstaller(targetDir);

    onProgress(const InstallProgress(0.94, '正在创建快捷方式…'));
    await _createShortcuts(targetDir, createDesktopShortcut);

    onProgress(const InstallProgress(1.0, '安装完成'));
  }

  String exePathIn(String targetDir) => '$targetDir\\$appExe';

  Future<void> launchApp(String targetDir) async {
    final exe = exePathIn(targetDir);
    if (await File(exe).exists()) {
      await Process.start(exe, const [], workingDirectory: targetDir);
    }
  }

  Future<void> _killRunning() async {
    final image = appExe.endsWith('.exe') ? appExe : '$appExe.exe';
    try {
      await Process.run('taskkill', ['/F', '/IM', image, '/T']);
    } catch (_) {
      // 未运行则忽略。
    }
  }

  Future<void> _writeRegistry(String targetDir) async {
    await _regWrite('HKCU\\$regKey', 'InstallPath', targetDir);
    await _regWrite('HKCU\\$regKey', 'Version', appVersion);

    final uk = 'HKCU\\$_uninstallKey';
    await _regWrite(uk, 'DisplayName', appName);
    await _regWrite(uk, 'DisplayVersion', appVersion);
    await _regWrite(uk, 'Publisher', publisher);
    await _regWrite(uk, 'InstallLocation', targetDir);
    await _regWrite(uk, 'DisplayIcon', '$targetDir\\$appExe');
    await _regWrite(uk, 'NoModify', '1', type: 'REG_DWORD');
    await _regWrite(uk, 'NoRepair', '1', type: 'REG_DWORD');
  }

  /// 卸载器：这里写一个自删除脚本 + 注册表清理。
  /// 采用一个批处理作为 uninstall.exe 的替代不合适（需 .exe），
  /// 因此生成 uninstall.cmd 并把 UninstallString 指向它。
  Future<void> _writeUninstaller(String targetDir) async {
    final cmd = File('$targetDir\\uninstall.cmd');
    final script = StringBuffer()
      ..writeln('@echo off')
      ..writeln('taskkill /F /IM $appExe /T >nul 2>&1')
      ..writeln('reg delete "HKCU\\$regKey" /f >nul 2>&1')
      ..writeln('reg delete "HKCU\\$_uninstallKey" /f >nul 2>&1')
      ..writeln(
          'del "%USERPROFILE%\\Desktop\\$appName.lnk" >nul 2>&1')
      ..writeln(
          'del "%APPDATA%\\Microsoft\\Windows\\Start Menu\\Programs\\$appName.lnk" >nul 2>&1')
      ..writeln('timeout /t 1 /nobreak >nul')
      ..writeln('rmdir /s /q "$targetDir"');
    await cmd.writeAsString(script.toString());

    // 将 UninstallString 指向 cmd（控制面板可调用）。
    await _regWrite('HKCU\\$_uninstallKey', 'UninstallString',
        'cmd /c "$targetDir\\uninstall.cmd"');
  }

  Future<void> _createShortcuts(String targetDir, bool desktop) async {
    final exe = '$targetDir\\$appExe';
    final startMenu =
        '${Platform.environment['APPDATA']}\\Microsoft\\Windows\\Start Menu\\Programs\\$appName.lnk';
    await _createLnk(startMenu, exe, targetDir);
    if (desktop) {
      final desktopLnk =
          '${Platform.environment['USERPROFILE']}\\Desktop\\$appName.lnk';
      await _createLnk(desktopLnk, exe, targetDir);
    }
  }

  Future<void> _createLnk(String lnkPath, String target, String workDir) async {
    final ps = '\$s=(New-Object -ComObject WScript.Shell).CreateShortcut('
        "'$lnkPath'); "
        "\$s.TargetPath='$target'; "
        "\$s.WorkingDirectory='$workDir'; "
        "\$s.IconLocation='$target,0'; "
        '\$s.Save()';
    await Process.run('powershell', ['-NoProfile', '-Command', ps]);
  }

  Future<String?> _regRead(String key, String name) async {
    final res = await Process.run('reg', ['query', key, '/v', name]);
    if (res.exitCode != 0) return null;
    final out = (res.stdout as String).split('\n');
    for (final line in out) {
      final trimmed = line.trim();
      if (trimmed.startsWith(name)) {
        // 形如: Name    REG_SZ    Value
        final idx = trimmed.indexOf('REG_');
        if (idx < 0) continue;
        final afterType = trimmed.substring(idx);
        final parts = afterType.split(RegExp(r'\s{2,}|\t'));
        if (parts.length >= 2) {
          return parts.sublist(1).join(' ').trim();
        }
      }
    }
    return null;
  }

  Future<void> _regWrite(String key, String name, String value,
      {String type = 'REG_SZ'}) async {
    await Process.run('reg', [
      'add',
      key,
      '/v',
      name,
      '/t',
      type,
      '/d',
      value,
      '/f',
    ]);
  }
}

class InstallException implements Exception {
  InstallException(this.message);
  final String message;
  @override
  String toString() => message;
}
