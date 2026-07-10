import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/ai_provider.dart';
import '../domain/casting.dart';
import '../domain/interpreter.dart';

enum AiPhase { idle, loading, streaming, done, error }

class AiState {
  const AiState({
    this.settings = const AiSettings(),
    this.loaded = false,
    this.phase = AiPhase.idle,
    this.result,
    this.error,
    this.activeReadingId,
  });

  final AiSettings settings;
  final bool loaded; // 是否已从磁盘读取过配置
  final AiPhase phase;
  final String? result;
  final String? error;
  final String? activeReadingId; // 当前展示结果对应的卦 id

  AiProviderConfig? get activeProvider => settings.active;

  AiState copyWith({
    AiSettings? settings,
    bool? loaded,
    AiPhase? phase,
    String? result,
    bool clearResult = false,
    String? error,
    bool clearError = false,
    String? activeReadingId,
    bool clearReadingId = false,
  }) {
    return AiState(
      settings: settings ?? this.settings,
      loaded: loaded ?? this.loaded,
      phase: phase ?? this.phase,
      result: clearResult ? null : (result ?? this.result),
      error: clearError ? null : (error ?? this.error),
      activeReadingId: clearReadingId
          ? null
          : (activeReadingId ?? this.activeReadingId),
    );
  }
}

class AiController extends StateNotifier<AiState> {
  AiController() : super(const AiState()) {
    _load();
  }

  static const _prefsKey = 'ai_settings_v2';
  static const _legacyKey = 'ai_provider_config_v1';

  final AiInterpreter _client = AiInterpreter();

  // 各卦 id -> 已生成的 AI 解读缓存（切换卦例时恢复）。
  final Map<String, String> _resultCache = {};

  StreamSubscription<String>? _sub;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        state = state.copyWith(
          settings: AiSettings.fromJson(json),
          loaded: true,
        );
        return;
      }
      // 迁移旧版单供应商配置。
      final legacy = prefs.getString(_legacyKey);
      if (legacy != null && legacy.isNotEmpty) {
        final cfg = AiProviderConfig.fromJson(
          jsonDecode(legacy) as Map<String, dynamic>,
        );
        final migrated = cfg.copyWith(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: '默认供应商',
        );
        final settings = AiSettings(
          providers: [migrated],
          activeId: migrated.id,
        );
        state = state.copyWith(settings: settings, loaded: true);
        await _persist(settings);
        return;
      }
    } catch (_) {
      // 读取失败则退回空配置。
    }
    state = state.copyWith(loaded: true);
  }

  Future<void> _persist(AiSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(settings.toJson()));
    } catch (_) {}
  }

  // ---- 供应商管理 ----

  Future<void> upsertProvider(AiProviderConfig cfg) async {
    final list = List<AiProviderConfig>.from(state.settings.providers);
    final idx = list.indexWhere((p) => p.id == cfg.id);
    if (idx >= 0) {
      list[idx] = cfg;
    } else {
      list.add(cfg);
    }
    final activeId = state.settings.activeId.isEmpty
        ? cfg.id
        : state.settings.activeId;
    final settings = state.settings.copyWith(
      providers: list,
      activeId: activeId,
    );
    state = state.copyWith(settings: settings);
    await _persist(settings);
  }

  Future<void> deleteProvider(String id) async {
    final list = state.settings.providers.where((p) => p.id != id).toList();
    var activeId = state.settings.activeId;
    if (activeId == id) {
      activeId = list.isNotEmpty ? list.first.id : '';
    }
    final settings = state.settings.copyWith(
      providers: list,
      activeId: activeId,
    );
    state = state.copyWith(settings: settings);
    await _persist(settings);
  }

  Future<void> setActive(String id) async {
    final settings = state.settings.copyWith(activeId: id);
    state = state.copyWith(settings: settings);
    await _persist(settings);
  }

  /// 测试连通性；成功返回 null，失败返回错误信息。
  Future<String?> testConnection(AiProviderConfig config) async {
    try {
      await _client.testConnection(config);
      return null;
    } on AiException catch (e) {
      return e.message;
    } catch (e) {
      return '未知错误：$e';
    }
  }

  // ---- 解卦结果与卦例切换 ----

  /// 切换当前展示的卦：若已有缓存结果则恢复，否则清空。
  void switchReading(String? readingId) {
    _sub?.cancel();
    _sub = null;
    if (readingId != null && _resultCache.containsKey(readingId)) {
      state = state.copyWith(
        phase: AiPhase.done,
        result: _resultCache[readingId],
        activeReadingId: readingId,
        clearError: true,
      );
    } else {
      state = state.copyWith(
        phase: AiPhase.idle,
        clearResult: true,
        clearError: true,
        activeReadingId: readingId,
        clearReadingId: readingId == null,
      );
    }
  }

  void resetResult() {
    _sub?.cancel();
    _sub = null;
    state = state.copyWith(
      phase: AiPhase.idle,
      clearResult: true,
      clearError: true,
    );
  }

  /// 中断正在进行的流式生成，保留已产出的内容。
  void stopStreaming() {
    if (state.phase != AiPhase.streaming) return;
    _sub?.cancel();
    _sub = null;
    final text = (state.result ?? '').trim();
    final id = state.activeReadingId;
    if (text.isEmpty) {
      state = state.copyWith(phase: AiPhase.idle, clearResult: true);
    } else {
      if (id != null) _resultCache[id] = text;
      state = state.copyWith(phase: AiPhase.done, result: text);
    }
  }

  Future<void> analyze(Reading reading, Interpretation local) async {
    final provider = state.activeProvider;
    if (provider == null || !provider.isConfigured) {
      state = state.copyWith(
        phase: AiPhase.error,
        error: '尚未配置可用的 AI 供应商，请点击右上角设置添加。',
        clearResult: true,
        activeReadingId: reading.id,
      );
      return;
    }

    _sub?.cancel();
    _sub = null;
    state = state.copyWith(
      phase: AiPhase.loading,
      clearResult: true,
      clearError: true,
      activeReadingId: reading.id,
    );

    if (provider.stream) {
      await _analyzeStreaming(provider, reading, local);
    } else {
      await _analyzeOnce(provider, reading, local);
    }
  }

  Future<void> _analyzeOnce(
    AiProviderConfig provider,
    Reading reading,
    Interpretation local,
  ) async {
    try {
      final text = await _client.analyze(
        config: provider,
        reading: reading,
        local: local,
      );
      _resultCache[reading.id] = text;
      state = state.copyWith(phase: AiPhase.done, result: text);
    } on AiException catch (e) {
      state = state.copyWith(phase: AiPhase.error, error: e.message);
    } catch (e) {
      state = state.copyWith(phase: AiPhase.error, error: '解卦失败：$e');
    }
  }

  Future<void> _analyzeStreaming(
    AiProviderConfig provider,
    Reading reading,
    Interpretation local,
  ) async {
    final completer = Completer<void>();
    final buffer = StringBuffer();
    var started = false;
    _sub = _client
        .analyzeStream(config: provider, reading: reading, local: local)
        .listen(
          (piece) {
            buffer.write(piece);
            if (!started) {
              started = true;
              state = state.copyWith(phase: AiPhase.streaming);
            }
            state = state.copyWith(result: buffer.toString());
          },
          onError: (Object e) {
            final msg = e is AiException ? e.message : '解卦失败：$e';
            // 若已经产出部分内容，则保留并追加错误提示。
            if (buffer.isNotEmpty) {
              state = state.copyWith(
                phase: AiPhase.done,
                result: buffer.toString(),
              );
              _resultCache[reading.id] = buffer.toString();
            } else {
              state = state.copyWith(phase: AiPhase.error, error: msg);
            }
            if (!completer.isCompleted) completer.complete();
          },
          onDone: () {
            final text = buffer.toString().trim();
            if (text.isEmpty) {
              state = state.copyWith(phase: AiPhase.error, error: '供应商返回内容为空。');
            } else {
              _resultCache[reading.id] = text;
              state = state.copyWith(phase: AiPhase.done, result: text);
            }
            if (!completer.isCompleted) completer.complete();
          },
          cancelOnError: true,
        );
    await completer.future;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final aiProvider = StateNotifierProvider<AiController, AiState>(
  (ref) => AiController(),
);
