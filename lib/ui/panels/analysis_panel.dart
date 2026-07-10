import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/casting.dart';
import '../../domain/interpreter.dart';
import '../../domain/location_context.dart';
import '../../state/ai_state.dart';
import '../home_page.dart';
import '../theme.dart';
import '../widgets/ai_settings_dialog.dart';
import '../widgets/taiji_loader.dart';

class AnalysisPanel extends ConsumerWidget {
  const AnalysisPanel({
    super.key,
    required this.reading,
    required this.interpretation,
  });
  final Reading? reading;
  final Interpretation? interpretation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ai = ref.watch(aiProvider);
    return XuanCard(
      title: '断卦',
      step: '叁',
      icon: Icons.auto_awesome_outlined,
      padding: EdgeInsets.zero,
      trailing: (reading == null || interpretation == null)
          ? null
          : _AiActionButton(reading: reading!, interp: interpretation!),
      child: AnimatedSwitcher(
        duration: XuanMotion.reveal,
        switchInCurve: XuanMotion.emphasized,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, anim) =>
            FadeTransition(opacity: anim, child: child),
        child: (reading == null || interpretation == null)
            ? const _Empty(key: ValueKey('empty'))
            : _Body(
                key: ValueKey(reading!.date.microsecondsSinceEpoch),
                reading: reading!,
                interp: interpretation!,
                ai: ai,
              ),
      ),
    );
  }
}

class _AiActionButton extends ConsumerWidget {
  const _AiActionButton({required this.reading, required this.interp});
  final Reading reading;
  final Interpretation interp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ai = ref.watch(aiProvider);
    final loading = ai.phase == AiPhase.loading;
    return _MiniButton(
      icon: loading ? Icons.hourglass_top : Icons.auto_awesome,
      label: loading ? 'AI 解卦中' : 'AI 解卦',
      onTap: loading
          ? null
          : () => ref.read(aiProvider.notifier).analyze(reading, interp),
    );
  }
}

class _MiniButton extends StatefulWidget {
  const _MiniButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  State<_MiniButton> createState() => _MiniButtonState();
}

class _MiniButtonState extends State<_MiniButton> {
  bool _hover = false;
  bool _pressed = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        onHover: (value) => setState(() => _hover = value),
        onHighlightChanged: (value) => setState(() => _pressed = value),
        onFocusChange: (value) => setState(() => _focused = value),
        borderRadius: BorderRadius.circular(5),
        mouseCursor: enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: AnimatedScale(
          scale: _pressed ? 0.94 : 1,
          duration: XuanMotion.fast,
          curve: XuanMotion.ease,
          child: AnimatedContainer(
            duration: XuanMotion.fast,
            curve: XuanMotion.ease,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: enabled
                  ? (_hover
                        ? XuanTheme.gold.withValues(alpha: 0.2)
                        : XuanTheme.gold.withValues(alpha: 0.1))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: _focused
                    ? XuanTheme.textMain
                    : enabled
                    ? XuanTheme.gold.withValues(alpha: 0.5)
                    : XuanTheme.line,
                width: _focused ? 1.6 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.icon,
                  size: 13,
                  color: enabled ? XuanTheme.goldSoft : XuanTheme.textDim,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: enabled ? XuanTheme.goldSoft : XuanTheme.textDim,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Breathing(
          minOpacity: 0.5,
          minScale: 0.985,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AnalysisEmptyGlyph(),
              SizedBox(height: 20),
              Text(
                '静候卦成',
                style: TextStyle(color: XuanTheme.textMuted, fontSize: 13.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnalysisEmptyGlyph extends StatelessWidget {
  const _AnalysisEmptyGlyph();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final width in [1.0, 0.72, 0.88]) ...[
            FractionallySizedBox(
              widthFactor: width,
              child: Container(
                height: 7,
                decoration: BoxDecoration(
                  color: XuanTheme.gold.withValues(alpha: 0.34),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    super.key,
    required this.reading,
    required this.interp,
    required this.ai,
  });
  final Reading reading;
  final Interpretation interp;
  final AiState ai;

  @override
  Widget build(BuildContext context) {
    // 逐块错峰入场（AI 区域独立更新，不参与错峰）。
    var i = 0;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StaggeredReveal(index: i++, child: _questionBlock()),
          const SizedBox(height: 14),
          if (reading.locationContext != null) ...[
            StaggeredReveal(
              index: i++,
              child: _locationBlock(reading.locationContext!),
            ),
            const SizedBox(height: 14),
          ],
          _AiBlock(ai: ai),
          StaggeredReveal(
            index: i++,
            child: _section('卦象概览', [interp.summary, ...interp.points]),
          ),
          const SizedBox(height: 14),
          StaggeredReveal(
            index: i++,
            child: _section('世应关系', [interp.shiYingNote]),
          ),
          if (interp.movingNotes.isNotEmpty) ...[
            const SizedBox(height: 14),
            StaggeredReveal(
              index: i++,
              child: _section(
                '动爻',
                interp.movingNotes,
                accent: XuanTheme.cinnabar,
              ),
            ),
          ],
          if (interp.kongWang.isNotEmpty) ...[
            const SizedBox(height: 14),
            StaggeredReveal(index: i++, child: _section('旬空', interp.kongWang)),
          ],
          const SizedBox(height: 16),
          StaggeredReveal(
            index: i++,
            child: Container(
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 2),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: XuanTheme.lineSoft)),
              ),
              child: const Text(
                '卦爻之说仅供参照静思，事在人为，趋吉避凶终由己心。',
                style: TextStyle(
                  color: XuanTheme.textDim,
                  fontSize: 11.5,
                  height: 1.7,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _questionBlock() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: XuanTheme.gold.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border(
          left: BorderSide(
            color: XuanTheme.gold.withValues(alpha: 0.72),
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '所问',
            style: TextStyle(color: XuanTheme.gold, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            reading.question,
            style: const TextStyle(
              color: XuanTheme.textMain,
              fontSize: 13.5,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _locationBlock(LocationContext location) {
    final events = location.recentEvents.take(3).toList();
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
      decoration: BoxDecoration(
        color: XuanTheme.jade.withValues(alpha: 0.065),
        borderRadius: BorderRadius.circular(6),
        border: Border(
          left: BorderSide(
            color: XuanTheme.jade.withValues(alpha: 0.82),
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 14,
                color: XuanTheme.jade,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  location.placeLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: XuanTheme.textMain,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            '${location.coordinateLabel} · 精度约 '
            '${location.accuracyMeters.toStringAsFixed(0)} 米',
            style: const TextStyle(color: XuanTheme.textDim, fontSize: 10.5),
          ),
          if (location.weatherSummary.isNotEmpty) ...[
            const SizedBox(height: 8),
            _contextLine(Icons.air, location.weatherSummary),
          ],
          for (final fact in location.regionalFacts.take(2)) ...[
            const SizedBox(height: 6),
            _contextLine(Icons.public_outlined, fact),
          ],
          if (events.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              '近期公开事件',
              style: TextStyle(
                color: XuanTheme.jade,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 5),
            for (final event in events)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 3,
                      height: 3,
                      margin: const EdgeInsets.only(top: 7, right: 7),
                      decoration: const BoxDecoration(
                        color: XuanTheme.jade,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${event.title} · ${event.sourceName}',
                        style: const TextStyle(
                          color: XuanTheme.textMuted,
                          fontSize: 10.8,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (location.warnings.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              '未取得：${location.warnings.join('、')}',
              style: const TextStyle(
                color: XuanTheme.textDim,
                fontSize: 10,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _contextLine(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 12, color: XuanTheme.textDim),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: XuanTheme.textMuted,
              fontSize: 10.8,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _section(
    String title,
    List<String> lines, {
    Color accent = XuanTheme.gold,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 3, height: 13, color: accent),
            const SizedBox(width: 7),
            Text(
              title,
              style: const TextStyle(
                color: XuanTheme.textMain,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 7, right: 8),
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    line,
                    style: const TextStyle(
                      color: XuanTheme.textMain,
                      fontSize: 12.5,
                      height: 1.7,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// AI 解卦区域：随状态切换（空/加载/结果/错误）。
class _AiBlock extends ConsumerWidget {
  const _AiBlock({required this.ai});
  final AiState ai;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Widget content;
    switch (ai.phase) {
      case AiPhase.loading:
        content = const _AiLoading(key: ValueKey('ai-loading'));
        break;
      case AiPhase.streaming:
        content = _AiStreaming(
          key: const ValueKey('ai-streaming'),
          text: ai.result ?? '',
          onStop: () => ref.read(aiProvider.notifier).stopStreaming(),
        );
        break;
      case AiPhase.done:
        content = _AiResult(
          key: const ValueKey('ai-done'),
          text: ai.result ?? '',
          onCopy: () => Clipboard.setData(ClipboardData(text: ai.result ?? '')),
          onClose: () => ref.read(aiProvider.notifier).resetResult(),
        );
        break;
      case AiPhase.error:
        content = _AiError(
          key: const ValueKey('ai-error'),
          message: ai.error ?? '未知错误',
          onSettings: () => showAiSettingsDialog(context),
          onDismiss: () => ref.read(aiProvider.notifier).resetResult(),
        );
        break;
      case AiPhase.idle:
        content = const SizedBox(
          key: ValueKey('ai-idle'),
          width: double.infinity,
        );
        break;
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, anim) =>
            FadeTransition(opacity: anim, child: child),
        child: content,
      ),
    );
  }
}

class _AiLoading extends StatelessWidget {
  const _AiLoading({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: XuanTheme.inkRaised,
        borderRadius: BorderRadius.circular(6),
        border: Border(
          left: BorderSide(
            color: XuanTheme.gold.withValues(alpha: 0.7),
            width: 2,
          ),
        ),
      ),
      child: const Row(
        children: [
          TaijiLoader(size: 44),
          SizedBox(width: 16),
          Expanded(child: _AiLoadingLines()),
        ],
      ),
    );
  }
}

class _AiLoadingLines extends StatelessWidget {
  const _AiLoadingLines();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '正在参详卦象',
          style: TextStyle(
            color: XuanTheme.goldSoft,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        for (final width in [1.0, 0.78, 0.9]) ...[
          FractionallySizedBox(
            widthFactor: width,
            child: Container(
              height: 5,
              decoration: BoxDecoration(
                color: XuanTheme.textDim.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 7),
        ],
      ],
    );
  }
}

class _AiResult extends StatelessWidget {
  const _AiResult({
    super.key,
    required this.text,
    required this.onCopy,
    required this.onClose,
  });
  final String text;
  final VoidCallback onCopy;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return FadeSlideIn(
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: XuanTheme.inkRaised,
          borderRadius: BorderRadius.circular(6),
          border: Border(
            left: BorderSide(
              color: XuanTheme.gold.withValues(alpha: 0.82),
              width: 2,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, size: 14, color: XuanTheme.gold),
                const SizedBox(width: 7),
                const Text(
                  'AI 参详',
                  style: TextStyle(
                    color: XuanTheme.goldSoft,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                _iconAction(Icons.copy_all_outlined, '复制', onCopy),
                const SizedBox(width: 4),
                _iconAction(Icons.close, '收起', onClose),
              ],
            ),
            const SizedBox(height: 10),
            SelectableText(
              text,
              style: const TextStyle(
                color: XuanTheme.textMain,
                fontSize: 12.8,
                height: 1.85,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconAction(IconData icon, String tip, VoidCallback onTap) {
    return Tooltip(
      message: tip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 15, color: XuanTheme.textDim),
        ),
      ),
    );
  }
}

/// AI 流式解卦卡片：逐字吐出内容，头部提供“停止”。
class _AiStreaming extends StatelessWidget {
  const _AiStreaming({super.key, required this.text, required this.onStop});
  final String text;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return FadeSlideIn(
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: XuanTheme.inkRaised,
          borderRadius: BorderRadius.circular(6),
          border: Border(
            left: BorderSide(
              color: XuanTheme.gold.withValues(alpha: 0.82),
              width: 2,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const _StreamingDot(),
                const SizedBox(width: 7),
                const Text(
                  'AI 参详中',
                  style: TextStyle(
                    color: XuanTheme.goldSoft,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Tooltip(
                  message: '停止生成',
                  child: InkWell(
                    onTap: onStop,
                    borderRadius: BorderRadius.circular(5),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.stop_circle_outlined,
                        size: 16,
                        color: XuanTheme.textDim,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Typewriter(
              text: text,
              active: true,
              style: const TextStyle(
                color: XuanTheme.textMain,
                fontSize: 12.8,
                height: 1.85,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 流式指示：脉动的鎏金圆点。
class _StreamingDot extends StatelessWidget {
  const _StreamingDot();

  @override
  Widget build(BuildContext context) {
    return Breathing(
      duration: const Duration(milliseconds: 1000),
      minScale: 0.68,
      minOpacity: 0.42,
      child: Container(
        width: 9,
        height: 9,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: XuanTheme.gold,
        ),
      ),
    );
  }
}

class _AiError extends StatelessWidget {
  const _AiError({
    super.key,
    required this.message,
    required this.onSettings,
    required this.onDismiss,
  });
  final String message;
  final VoidCallback onSettings;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: XuanTheme.cinnabar.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: XuanTheme.cinnabar.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.error_outline,
                size: 15,
                color: XuanTheme.cinnabar,
              ),
              const SizedBox(width: 7),
              const Expanded(
                child: Text(
                  'AI 解卦未成功',
                  style: TextStyle(
                    color: XuanTheme.cinnabar,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              InkWell(
                onTap: onDismiss,
                child: const Icon(
                  Icons.close,
                  size: 14,
                  color: XuanTheme.textDim,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              color: XuanTheme.textMain,
              fontSize: 12,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onSettings,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.settings_outlined, size: 13, color: XuanTheme.gold),
                SizedBox(width: 5),
                Text(
                  '前往供应商配置',
                  style: TextStyle(color: XuanTheme.goldSoft, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
