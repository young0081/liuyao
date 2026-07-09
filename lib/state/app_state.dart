import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/casting.dart';
import '../domain/interpreter.dart';

enum CastMethod { coins, manual }

class DivinationState {
  const DivinationState({
    this.question = '',
    this.method = CastMethod.coins,
    this.tossing = false,
    this.castStep = 0,
    this.castReveal = const [null, null, null, null, null, null],
    this.reading,
    this.interpretation,
    this.manualValues = const [7, 7, 7, 7, 7, 7],
    this.history = const [],
  });

  final String question;
  final CastMethod method;
  final bool tossing;
  final int castStep; // 摇卦动画进度 0..6
  final List<int?> castReveal; // 逐爻揭示的掷值(6/7/8/9)，null 表示未揭示
  final Reading? reading;
  final Interpretation? interpretation;
  final List<int> manualValues; // 初->上, 6/7/8/9
  final List<Reading> history;

  DivinationState copyWith({
    String? question,
    CastMethod? method,
    bool? tossing,
    int? castStep,
    List<int?>? castReveal,
    Reading? reading,
    bool clearReading = false,
    Interpretation? interpretation,
    List<int>? manualValues,
    List<Reading>? history,
  }) {
    return DivinationState(
      question: question ?? this.question,
      method: method ?? this.method,
      tossing: tossing ?? this.tossing,
      castStep: castStep ?? this.castStep,
      castReveal: castReveal ?? this.castReveal,
      reading: clearReading ? null : (reading ?? this.reading),
      interpretation:
          clearReading ? null : (interpretation ?? this.interpretation),
      manualValues: manualValues ?? this.manualValues,
      history: history ?? this.history,
    );
  }
}

class DivinationController extends StateNotifier<DivinationState> {
  DivinationController() : super(const DivinationState()) {
    _loadHistory();
  }

  final Caster _caster = Caster();
  final Interpreter _interpreter = Interpreter();

  static const _historyKey = 'divination_history_v1';

  void setQuestion(String q) => state = state.copyWith(question: q);

  void setMethod(CastMethod m) => state = state.copyWith(method: m);

  void setManualYao(int index, int value) {
    final next = List<int>.from(state.manualValues);
    next[index] = value;
    state = state.copyWith(manualValues: next);
  }

  /// 摇卦：逐爻演示六次投掷的完整过程。
  Future<void> castByCoins() async {
    if (state.tossing) return;
    final tosses = _caster.tossThreeCoins();
    state = state.copyWith(
      tossing: true,
      clearReading: true,
      castStep: 0,
      castReveal: const [null, null, null, null, null, null],
    );
    // 逐爻(初->上)揭示，每爻先旋转再定格。
    for (var i = 0; i < 6; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 620));
      final reveal = List<int?>.from(state.castReveal);
      reveal[i] = tosses[i].value;
      state = state.copyWith(castStep: i + 1, castReveal: reveal);
      // 定格片刻。
      await Future<void>.delayed(const Duration(milliseconds: 260));
    }
    await Future<void>.delayed(const Duration(milliseconds: 350));
    _finish(tosses, '三钱摇卦');
  }

  void castManual() {
    final tosses = _caster.fromValues(state.manualValues);
    _finish(tosses, '手动排爻');
  }

  void _finish(List tosses, String method) {
    final reading = _caster.castFromTosses(
      tosses: tosses.cast(),
      question: state.question.trim().isEmpty
          ? '（未填写所问之事）'
          : state.question.trim(),
      method: method,
    );
    final interp = _interpreter.interpret(reading);
    final history = [reading, ...state.history].take(50).toList();
    state = state.copyWith(
      tossing: false,
      castStep: 6,
      reading: reading,
      interpretation: interp,
      history: history,
    );
    _saveHistory(history);
  }

  void loadFromHistory(int index) {
    if (index < 0 || index >= state.history.length) return;
    final r = state.history[index];
    state = state.copyWith(
      reading: r,
      interpretation: _interpreter.interpret(r),
      question: r.question,
    );
  }

  void clear() => state = state.copyWith(clearReading: true);

  Future<void> deleteHistory(int index) async {
    if (index < 0 || index >= state.history.length) return;
    final next = List<Reading>.from(state.history)..removeAt(index);
    state = state.copyWith(history: next);
    await _saveHistory(next);
  }

  Future<void> clearHistory() async {
    state = state.copyWith(history: const []);
    await _saveHistory(const []);
  }

  // ---- 持久化 ----

  Future<void> _saveHistory(List<Reading> history) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = history
          .map((r) => {
                'q': r.question,
                'm': r.method,
                't': r.date.microsecondsSinceEpoch,
                'v': r.tossValues,
              })
          .toList();
      await prefs.setString(_historyKey, jsonEncode(list));
    } catch (_) {
      // 持久化失败不阻断使用。
    }
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_historyKey);
      if (raw == null || raw.isEmpty) return;
      final list = jsonDecode(raw) as List<dynamic>;
      final restored = <Reading>[];
      for (final e in list) {
        final m = e as Map<String, dynamic>;
        final values = (m['v'] as List<dynamic>).map((x) => x as int).toList();
        final at = DateTime.fromMicrosecondsSinceEpoch(m['t'] as int);
        final reading = _caster.castFromTosses(
          tosses: _caster.fromValues(values),
          question: m['q'] as String? ?? '',
          method: m['m'] as String? ?? '三钱摇卦',
          at: at,
        );
        restored.add(reading);
      }
      state = state.copyWith(history: restored);
    } catch (_) {
      // 读取失败则忽略。
    }
  }
}

final divinationProvider =
    StateNotifierProvider<DivinationController, DivinationState>(
  (ref) => DivinationController(),
);
