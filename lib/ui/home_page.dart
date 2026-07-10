import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_state.dart';
import '../state/ai_state.dart';
import 'panels/analysis_panel.dart';
import 'panels/cast_panel.dart';
import 'panels/chart_panel.dart';
import 'platform.dart';
import 'theme.dart';
import 'widgets/title_bar.dart';
import 'widgets/taiji_loader.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 起新卦时清除上一卦的 AI 结果，避免串卦。
    ref.listen(divinationProvider, (prev, next) {
      if (prev?.reading?.id != next.reading?.id) {
        ref.read(aiProvider.notifier).switchReading(next.reading?.id);
      }
    });
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ClipRRect(
        borderRadius: isDesktopPlatform
            ? BorderRadius.circular(10)
            : BorderRadius.zero,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: XuanTheme.ink,
            border: isDesktopPlatform
                ? Border.all(color: XuanTheme.lineSoft)
                : null,
          ),
          child: const Column(
            children: [
              XuanTitleBar(),
              Expanded(child: _ResponsiveBody()),
            ],
          ),
        ),
      ),
    );
  }
}

/// 宽桌面三栏并排；窄窗口切为页签，避免信息列被压缩。
class _ResponsiveBody extends StatelessWidget {
  const _ResponsiveBody();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (isDesktopPlatform && constraints.maxWidth >= 1080) {
          return const _DesktopBody();
        }
        return _TabbedBody(compactDesktop: isDesktopPlatform);
      },
    );
  }
}

class _DesktopBody extends StatelessWidget {
  const _DesktopBody();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(
            width: 316,
            child: StaggeredReveal(index: 0, child: _CastColumn()),
          ),
          const SizedBox(width: 12),
          const Expanded(
            flex: 5,
            child: StaggeredReveal(index: 1, child: _ChartColumn()),
          ),
          const SizedBox(width: 12),
          const Expanded(
            flex: 4,
            child: StaggeredReveal(index: 2, child: _AnalysisColumn()),
          ),
        ],
      ),
    );
  }
}

/// 移动端使用底部页签；桌面窄窗口使用顶部页签。
class _TabbedBody extends ConsumerStatefulWidget {
  const _TabbedBody({required this.compactDesktop});

  final bool compactDesktop;

  @override
  ConsumerState<_TabbedBody> createState() => _TabbedBodyState();
}

class _TabbedBodyState extends ConsumerState<_TabbedBody>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(divinationProvider.select((state) => state.reading?.id), (
      previous,
      next,
    ) {
      if (next != null && previous != next) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _tab.animateTo(
              1,
              duration: XuanMotion.page,
              curve: XuanMotion.emphasized,
            );
          }
        });
      }
    });

    final pages = TabBarView(
      controller: _tab,
      physics: const BouncingScrollPhysics(),
      children: const [
        Padding(
          padding: EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: _CastColumn(),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: _ChartColumn(),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: _AnalysisColumn(),
        ),
      ],
    );

    if (widget.compactDesktop) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: _FlowTabs(controller: _tab),
          ),
          Expanded(child: pages),
        ],
      );
    }

    return Column(
      children: [
        Expanded(child: pages),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            child: _FlowTabs(controller: _tab),
          ),
        ),
      ],
    );
  }
}

class _FlowTabs extends StatelessWidget {
  const _FlowTabs({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: XuanTheme.inkPanel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: XuanTheme.lineSoft),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55070806),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: TabBar(
        controller: controller,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: XuanTheme.gold.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: XuanTheme.gold.withValues(alpha: 0.42)),
        ),
        labelColor: XuanTheme.goldSoft,
        unselectedLabelColor: XuanTheme.textDim,
        labelStyle: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 12.5),
        tabs: const [
          _FlowTab(icon: Icons.toll_outlined, label: '起卦'),
          _FlowTab(icon: Icons.view_agenda_outlined, label: '排盘'),
          _FlowTab(icon: Icons.auto_awesome_outlined, label: '断卦'),
        ],
      ),
    );
  }
}

class _FlowTab extends StatelessWidget {
  const _FlowTab({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Tab(
      height: 42,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [Icon(icon, size: 15), const SizedBox(width: 6), Text(label)],
      ),
    );
  }
}

/// 起卦栏：随整体状态更新（含输入、方式、历史）。
class _CastColumn extends ConsumerWidget {
  const _CastColumn();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(divinationProvider);
    return CastPanel(state: state);
  }
}

/// 排盘栏：仅在卦发生变化时重建（打字不触发）。
class _ChartColumn extends ConsumerWidget {
  const _ChartColumn();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reading = ref.watch(divinationProvider.select((s) => s.reading));
    return ChartPanel(reading: reading);
  }
}

/// 断卦栏：仅在卦或解读变化时重建。
class _AnalysisColumn extends ConsumerWidget {
  const _AnalysisColumn();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reading = ref.watch(divinationProvider.select((s) => s.reading));
    final interp = ref.watch(
      divinationProvider.select((s) => s.interpretation),
    );
    return AnalysisPanel(reading: reading, interpretation: interp);
  }
}

/// 通用面板容器。
class XuanCard extends StatelessWidget {
  const XuanCard({
    super.key,
    required this.child,
    required this.title,
    required this.step,
    required this.icon,
    this.trailing,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final String title;
  final String step;
  final IconData icon;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: XuanTheme.inkPanel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: XuanTheme.lineSoft),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66070806),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 50,
              padding: const EdgeInsets.fromLTRB(12, 0, 10, 0),
              decoration: const BoxDecoration(
                color: XuanTheme.inkPanel,
                border: Border(bottom: BorderSide(color: XuanTheme.lineSoft)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: XuanTheme.inkRaised,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: XuanTheme.line),
                    ),
                    child: Text(
                      step,
                      style: const TextStyle(
                        color: XuanTheme.goldSoft,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Icon(icon, size: 15, color: XuanTheme.gold),
                  const SizedBox(width: 7),
                  Text(
                    title,
                    style: const TextStyle(
                      color: XuanTheme.textMain,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  ?trailing,
                ],
              ),
            ),
            Expanded(
              child: Padding(padding: padding, child: child),
            ),
          ],
        ),
      ),
    );
  }
}
