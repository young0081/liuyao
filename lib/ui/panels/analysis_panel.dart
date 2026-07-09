import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/casting.dart';
import '../../domain/interpreter.dart';
import '../../state/ai_state.dart';
import '../home_page.dart';
import '../theme.dart';
import '../widgets/ai_settings_dialog.dart';
import '../widgets/taiji_loader.dart';

class AnalysisPanel extends ConsumerWidget {
  const AnalysisPanel(
      {super.key, required this.reading, required this.interpretation});
  final Reading? reading;
  final Interpretation? interpretation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ai = ref.watch(aiProvider);
    return XuanCard(
      title: '断卦',
      padding: EdgeInsets.zero,
      trailing: (reading == null || interpretation == null)
          ? null
          : _AiActionButton(reading: reading!, interp: interpretation!),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        switchInCurve: Curves.easeOutCubic,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: child,
        ),
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
  const _MiniButton(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  State<_MiniButton> createState() => _MiniButtonState();
}

class _MiniButtonState extends State<_MiniButton> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: enabled
                ? (_hover
                    ? XuanTheme.gold.withValues(alpha: 0.2)
                    : XuanTheme.gold.withValues(alpha: 0.1))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: enabled
                  ? XuanTheme.gold.withValues(alpha: 0.55)
                  : XuanTheme.line,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon,
                  size: 13,
                  color: enabled ? XuanTheme.goldSoft : XuanTheme.textDim),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  color: enabled ? XuanTheme.goldSoft : XuanTheme.textDim,
                  fontSize: 11.5,
                  letterSpacing: 0.5,
                ),
              ),
            ],
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
        padding: EdgeInsets.all(24),
        child: Breathing(
          minOpacity: 0.6,
          minScale: 0.98,
          child: Text(
            '得卦后，此处列出世应、用神、\n动爻与旬空之要点，供参详。',
            textAlign: TextAlign.center,
            style:
                TextStyle(color: XuanTheme.textDim, fontSize: 13, height: 1.8),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body(
      {super.key,
      required this.reading,
      required this.interp,
      required this.ai});
  final Reading reading;
  final Interpretation interp;
  final AiState ai;

  @override
  Widget build(BuildContext context) {
    // 逐块错峰入场（AI 区域独立更新，不参与错峰）。
    var i = 0;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StaggeredReveal(index: i++, child: _questionBlock()),
          const SizedBox(height: 14),
          _AiBlock(ai: ai),
          StaggeredReveal(
              index: i++,
              child: _section('卦象概览', [interp.summary, ...interp.points])),
          const SizedBox(height: 14),
          StaggeredReveal(
              index: i++, child: _section('世应关系', [interp.shiYingNote])),
          if (interp.movingNotes.isNotEmpty) ...[
            const SizedBox(height: 14),
            StaggeredReveal(
                index: i++,
                child: _section('动爻', interp.movingNotes,
                    accent: XuanTheme.cinnabar)),
          ],
          if (interp.kongWang.isNotEmpty) ...[
            const SizedBox(height: 14),
            StaggeredReveal(
                index: i++, child: _section('旬空', interp.kongWang)),
          ],
          const SizedBox(height: 16),
          StaggeredReveal(
            index: i++,
            child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: XuanTheme.inkRaised,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: XuanTheme.line),
            ),
            child: const Text(
              '卦爻之说仅供参照静思，事在人为，趋吉避凶终由己心。',
              style: TextStyle(
                  color: XuanTheme.textDim, fontSize: 11.5, height: 1.7),
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
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: XuanTheme.gold.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('所问',
              style: TextStyle(
                  color: XuanTheme.gold, fontSize: 11, letterSpacing: 2)),
          const SizedBox(height: 4),
          Text(reading.question,
              style: const TextStyle(
                  color: XuanTheme.textMain, fontSize: 13.5, height: 1.6)),
        ],
      ),
    );
  }

  Widget _section(String title, List<String> lines,
      {Color accent = XuanTheme.gold}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 3, height: 13, color: accent),
            const SizedBox(width: 7),
            Text(title,
                style: const TextStyle(
                    color: XuanTheme.textMain,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1)),
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
                        color: accent, shape: BoxShape.circle),
                  ),
                ),
                Expanded(
                  child: Text(line,
                      style: const TextStyle(
                          color: XuanTheme.textMain,
                          fontSize: 12.5,
                          height: 1.7)),
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
        content = const SizedBox(key: ValueKey('ai-idle'), width: double.infinity);
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
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: XuanTheme.inkRaised,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: XuanTheme.gold.withValues(alpha: 0.25)),
      ),
      child: const Center(
        child: TaijiLoader(size: 58, label: '正在参详卦象…'),
      ),
    );
  }
}

class _AiResult extends StatelessWidget {
  const _AiResult(
      {super.key,
      required this.text,
      required this.onCopy,
      required this.onClose});
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
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              XuanTheme.gold.withValues(alpha: 0.1),
              XuanTheme.gold.withValues(alpha: 0.03),
            ],
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: XuanTheme.gold.withValues(alpha: 0.45)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, size: 14, color: XuanTheme.gold),
                const SizedBox(width: 7),
                const Text('AI 参详',
                    style: TextStyle(
                        color: XuanTheme.goldSoft,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5)),
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
                  color: XuanTheme.textMain, fontSize: 12.8, height: 1.85),
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
  const _AiStreaming(
      {super.key, required this.text, required this.onStop});
  final String text;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return FadeSlideIn(
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              XuanTheme.gold.withValues(alpha: 0.1),
              XuanTheme.gold.withValues(alpha: 0.03),
            ],
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: XuanTheme.gold.withValues(alpha: 0.45)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const _StreamingDot(),
                const SizedBox(width: 7),
                const Text('AI 参详中',
                    style: TextStyle(
                        color: XuanTheme.goldSoft,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5)),
                const Spacer(),
                Tooltip(
                  message: '停止生成',
                  child: InkWell(
                    onTap: onStop,
                    borderRadius: BorderRadius.circular(5),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.stop_circle_outlined,
                          size: 16, color: XuanTheme.textDim),
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
                  color: XuanTheme.textMain, fontSize: 12.8, height: 1.85),
            ),
          ],
        ),
      ),
    );
  }
}

/// 流式指示：脉动的鎏金圆点。
class _StreamingDot extends StatefulWidget {
  const _StreamingDot();
  @override
  State<_StreamingDot> createState() => _StreamingDotState();
}

class _StreamingDotState extends State<_StreamingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        return Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: XuanTheme.gold.withValues(alpha: 0.4 + 0.6 * _c.value),
            boxShadow: [
              BoxShadow(
                color: XuanTheme.gold.withValues(alpha: 0.5 * _c.value),
                blurRadius: 6 * _c.value,
                spreadRadius: 1,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AiError extends StatelessWidget {
  const _AiError(
      {super.key,
      required this.message,
      required this.onSettings,
      required this.onDismiss});
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
              const Icon(Icons.error_outline,
                  size: 15, color: XuanTheme.cinnabar),
              const SizedBox(width: 7),
              const Expanded(
                child: Text('AI 解卦未成功',
                    style: TextStyle(
                        color: XuanTheme.cinnabar,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600)),
              ),
              InkWell(
                onTap: onDismiss,
                child: const Icon(Icons.close, size: 14,
                    color: XuanTheme.textDim),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(message,
              style: const TextStyle(
                  color: XuanTheme.textMain, fontSize: 12, height: 1.6)),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onSettings,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.settings_outlined, size: 13, color: XuanTheme.gold),
                SizedBox(width: 5),
                Text('前往供应商配置',
                    style: TextStyle(
                        color: XuanTheme.goldSoft, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
