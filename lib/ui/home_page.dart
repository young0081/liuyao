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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0E1116), Color(0xFF10151C), Color(0xFF0B0E12)],
          ),
        ),
        child: Column(
          children: [
            const XuanTitleBar(),
            Expanded(
              child: isDesktopPlatform
                  ? const _DesktopBody()
                  : const _MobileBody(),
            ),
          ],
        ),
      ),
    );
  }
}

/// 桌面：固定三栏并排（起卦 / 排盘 / 断卦）。
class _DesktopBody extends StatelessWidget {
  const _DesktopBody();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 316, child: _CastColumn()),
          SizedBox(width: 14),
          Expanded(flex: 5, child: _ChartColumn()),
          SizedBox(width: 14),
          Expanded(flex: 4, child: _AnalysisColumn()),
        ],
      ),
    );
  }
}

/// 移动：三个页签（起卦 / 排盘 / 断卦），每页占满高度。
class _MobileBody extends StatefulWidget {
  const _MobileBody();
  @override
  State<_MobileBody> createState() => _MobileBodyState();
}

class _MobileBodyState extends State<_MobileBody>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: XuanTheme.line)),
          ),
          child: TabBar(
            controller: _tab,
            indicatorColor: XuanTheme.gold,
            indicatorWeight: 2,
            labelColor: XuanTheme.textMain,
            unselectedLabelColor: XuanTheme.textDim,
            labelStyle: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 3),
            unselectedLabelStyle:
                const TextStyle(fontSize: 14, letterSpacing: 3),
            tabs: const [
              Tab(text: '起卦'),
              Tab(text: '排盘'),
              Tab(text: '断卦'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: const [
              Padding(padding: EdgeInsets.all(12), child: _CastColumn()),
              Padding(padding: EdgeInsets.all(12), child: _ChartColumn()),
              Padding(padding: EdgeInsets.all(12), child: _AnalysisColumn()),
            ],
          ),
        ),
      ],
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
    final reading =
        ref.watch(divinationProvider.select((s) => s.reading));
    return ChartPanel(reading: reading);
  }
}

/// 断卦栏：仅在卦或解读变化时重建。
class _AnalysisColumn extends ConsumerWidget {
  const _AnalysisColumn();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reading =
        ref.watch(divinationProvider.select((s) => s.reading));
    final interp =
        ref.watch(divinationProvider.select((s) => s.interpretation));
    return AnalysisPanel(reading: reading, interpretation: interp);
  }
}

/// 通用面板容器。
class XuanCard extends StatelessWidget {
  const XuanCard({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final String? title;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: XuanTheme.inkPanel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: XuanTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: XuanTheme.line),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 14,
                    color: XuanTheme.gold,
                    margin: const EdgeInsets.only(right: 8),
                  ),
                  Text(
                    title!,
                    style: const TextStyle(
                      color: XuanTheme.textMain,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
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
    );
  }
}
