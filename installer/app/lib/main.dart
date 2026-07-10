import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'config.dart';
import 'install_engine.dart';
import 'theme.dart';
import 'widgets/ambient_background.dart';
import 'widgets/title_bar.dart';
import 'screens/welcome_screen.dart';
import 'screens/location_screen.dart';
import 'screens/installing_screen.dart';
import 'screens/done_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  const options = WindowOptions(
    size: Size(920, 600),
    minimumSize: Size(920, 600),
    maximumSize: Size(920, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
    title: '玄机 · 六爻卦象 安装向导',
  );
  windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.setAsFrameless();
    await windowManager.setResizable(false);
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const InstallerApp());
}

class InstallerApp extends StatelessWidget {
  const InstallerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '玄机 · 六爻卦象 安装向导',
      debugShowCheckedModeBanner: false,
      theme: XuanTheme.build(),
      home: const InstallerShell(),
    );
  }
}

enum InstallStep { welcome, location, installing, done }

class InstallerShell extends StatefulWidget {
  const InstallerShell({super.key});

  @override
  State<InstallerShell> createState() => _InstallerShellState();
}

class _InstallerShellState extends State<InstallerShell> {
  final engine = InstallEngine(
    appName: InstallerConfig.appName,
    appExe: InstallerConfig.appExe,
    appVersion: InstallerConfig.appVersion,
    publisher: InstallerConfig.publisher,
    regKey: InstallerConfig.regKey,
    appId: InstallerConfig.appId,
  );

  InstallStep _step = InstallStep.welcome;
  InstalledInfo? _installed;
  InstallAction _action = InstallAction.fresh;
  bool _detecting = true;

  late String _targetDir = engine.defaultInstallDir;
  bool _desktopShortcut = true;

  double _progress = 0;
  String _progressMsg = '';
  final List<String> _log = [];
  bool _installing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _detect();
  }

  Future<void> _detect() async {
    final info = await engine.detectInstalled();
    if (!mounted) return;
    setState(() {
      _installed = info;
      _action = engine.actionFor(info);
      if (info != null && info.path.isNotEmpty) {
        _targetDir = info.path;
      }
      _detecting = false;
    });
  }

  void _goTo(InstallStep s) => setState(() => _step = s);

  Future<void> _startInstall() async {
    setState(() {
      _step = InstallStep.installing;
      _installing = true;
      _error = null;
      _progress = 0;
      _log.clear();
    });
    try {
      await engine.install(
        targetDir: _targetDir,
        createDesktopShortcut: _desktopShortcut,
        onProgress: (p) {
          if (!mounted) return;
          setState(() {
            _progress = p.fraction;
            _progressMsg = p.message;
            if (_log.isEmpty || _log.last != p.message) {
              _log.add(p.message);
            }
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _installing = false;
      });
      await Future<void>.delayed(const Duration(milliseconds: 650));
      if (!mounted) return;
      setState(() => _step = InstallStep.done);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _installing = false;
        _error = e.toString();
      });
    }
  }

  Future<bool> _closeGuard() async {
    if (!_installing) return true;
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => AlertDialog(
        backgroundColor: XuanTheme.inkPanel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: XuanTheme.line),
        ),
        title: const Text(
          '安装正在进行',
          style: TextStyle(color: XuanTheme.textMain),
        ),
        content: const Text(
          '安装尚未完成，确定要中止并退出吗？',
          style: TextStyle(color: XuanTheme.textDim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              '继续安装',
              style: TextStyle(color: XuanTheme.textDim),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              '中止退出',
              style: TextStyle(color: XuanTheme.cinnabar),
            ),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: XuanTheme.lineSoft, width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            children: [
              Positioned.fill(
                child: AmbientBackground(intensity: _installing ? 1.6 : 1.0),
              ),
              Column(
                children: [
                  InstallerTitleBar(onCloseGuard: _closeGuard),
                  _InstallerProgressRail(current: _step),
                  Expanded(child: _buildBody()),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final child = switch (_step) {
      InstallStep.welcome => WelcomeScreen(
        key: const ValueKey('welcome'),
        detecting: _detecting,
        action: _action,
        installed: _installed,
        version: engine.appVersion,
        tagline: InstallerConfig.tagline,
        onNext: () => _goTo(InstallStep.location),
      ),
      InstallStep.location => LocationScreen(
        key: const ValueKey('location'),
        targetDir: _targetDir,
        desktopShortcut: _desktopShortcut,
        action: _action,
        onChangeDir: (d) => setState(() => _targetDir = d),
        onToggleDesktop: (v) => setState(() => _desktopShortcut = v),
        onBack: () => _goTo(InstallStep.welcome),
        onInstall: _startInstall,
      ),
      InstallStep.installing => InstallingScreen(
        key: const ValueKey('installing'),
        progress: _progress,
        message: _progressMsg,
        log: _log,
        error: _error,
        onRetry: _startInstall,
        onQuit: () => exit(1),
      ),
      InstallStep.done => DoneScreen(
        key: const ValueKey('done'),
        action: _action,
        version: engine.appVersion,
        installDir: _targetDir,
        onLaunchAndClose: () async {
          await engine.launchApp(_targetDir);
          await windowManager.close();
        },
        onClose: () => windowManager.close(),
      ),
    };

    return AnimatedSwitcher(
      duration: XuanMotion.page,
      switchInCurve: XuanMotion.emphasized,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (c, anim) {
        final offset = Tween<Offset>(
          begin: const Offset(0.04, 0),
          end: Offset.zero,
        ).animate(anim);
        return FadeTransition(
          opacity: anim,
          child: SlideTransition(position: offset, child: c),
        );
      },
      child: child,
    );
  }
}

class _InstallerProgressRail extends StatelessWidget {
  const _InstallerProgressRail({required this.current});

  final InstallStep current;

  static const labels = ['检测', '位置', '安装', '完成'];

  @override
  Widget build(BuildContext context) {
    final currentIndex = current.index;
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 48),
      decoration: const BoxDecoration(
        color: XuanTheme.inkPanel,
        border: Border(bottom: BorderSide(color: XuanTheme.lineSoft)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            _ProgressNode(
              index: i,
              label: labels[i],
              active: i == currentIndex,
              completed: i < currentIndex,
            ),
            if (i < labels.length - 1)
              Expanded(
                child: AnimatedContainer(
                  duration: XuanMotion.standard,
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  color: i < currentIndex
                      ? XuanTheme.gold.withValues(alpha: 0.65)
                      : XuanTheme.line,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ProgressNode extends StatelessWidget {
  const _ProgressNode({
    required this.index,
    required this.label,
    required this.active,
    required this.completed,
  });

  final int index;
  final String label;
  final bool active;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final highlighted = active || completed;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: XuanMotion.standard,
          curve: XuanMotion.ease,
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? XuanTheme.gold.withValues(alpha: 0.16)
                : completed
                ? XuanTheme.gold
                : XuanTheme.inkRaised,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: highlighted ? XuanTheme.gold : XuanTheme.line,
            ),
          ),
          child: completed
              ? const Icon(Icons.check, size: 14, color: XuanTheme.ink)
              : Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: active ? XuanTheme.goldSoft : XuanTheme.textDim,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
        const SizedBox(width: 7),
        AnimatedDefaultTextStyle(
          duration: XuanMotion.standard,
          style: TextStyle(
            color: active
                ? XuanTheme.textMain
                : completed
                ? XuanTheme.goldSoft
                : XuanTheme.textDim,
            fontSize: 11.5,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
          child: Text(label),
        ),
      ],
    );
  }
}
