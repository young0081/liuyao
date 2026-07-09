import 'dart:convert';

import 'package:http/http.dart' as http;

import 'casting.dart';
import 'interpreter.dart';
import 'models.dart';

/// 第三方 AI 供应商配置（OpenAI 兼容协议）。
///
/// 绝大多数供应商（OpenAI / DeepSeek / Moonshot / 通义 / 智谱 / 本地 Ollama 等）
/// 都提供 `/chat/completions` 兼容端点，故以 baseUrl + apiKey + model 三要素抽象。
class AiProviderConfig {
  const AiProviderConfig({
    this.id = '',
    this.name = '未命名供应商',
    this.baseUrl = 'https://api.openai.com/v1',
    this.apiKey = '',
    this.model = 'gpt-4o-mini',
    this.temperature = 0.7,
    this.stream = true,
    this.systemPrompt = defaultSystemPrompt,
  });

  final String id; // 稳定唯一标识
  final String name; // 展示名称（用户自定义，如「我的 DeepSeek」）
  final String baseUrl;
  final String apiKey;
  final String model;
  final double temperature;
  final bool stream; // 是否流式输出
  final String systemPrompt;

  static const String defaultSystemPrompt =
      '你是一位沉稳温和的六爻卦理参详者。请依据用户给出的排盘数据（本卦、变卦、'
      '世应、六亲、六神、动爻、旬空、干支日辰）作条理清晰的解读，兼顾用神旺衰、'
      '动变去向与世应关系。语气平实、就事论事，给出可行的思考方向与提醒，'
      '不做绝对化、宿命论的断言；结尾点明「事在人为，仅供参考」。请用简体中文，'
      '分段清晰，可用小标题，但不要输出 Markdown 代码块。';

  bool get isConfigured => baseUrl.trim().isNotEmpty && apiKey.trim().isNotEmpty;

  AiProviderConfig copyWith({
    String? id,
    String? name,
    String? baseUrl,
    String? apiKey,
    String? model,
    double? temperature,
    bool? stream,
    String? systemPrompt,
  }) {
    return AiProviderConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      temperature: temperature ?? this.temperature,
      stream: stream ?? this.stream,
      systemPrompt: systemPrompt ?? this.systemPrompt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'model': model,
        'temperature': temperature,
        'stream': stream,
        'systemPrompt': systemPrompt,
      };

  factory AiProviderConfig.fromJson(Map<String, dynamic> json) {
    return AiProviderConfig(
      id: (json['id'] as String?)?.trim().isNotEmpty == true
          ? json['id'] as String
          : DateTime.now().microsecondsSinceEpoch.toString(),
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? json['name'] as String
          : '未命名供应商',
      baseUrl: (json['baseUrl'] as String?)?.trim().isNotEmpty == true
          ? json['baseUrl'] as String
          : 'https://api.openai.com/v1',
      apiKey: json['apiKey'] as String? ?? '',
      model: (json['model'] as String?)?.trim().isNotEmpty == true
          ? json['model'] as String
          : 'gpt-4o-mini',
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.7,
      stream: json['stream'] as bool? ?? true,
      systemPrompt: (json['systemPrompt'] as String?)?.trim().isNotEmpty == true
          ? json['systemPrompt'] as String
          : defaultSystemPrompt,
    );
  }
}

/// 多供应商设置：一组供应商 + 当前激活的 id。
class AiSettings {
  const AiSettings({this.providers = const [], this.activeId = ''});

  final List<AiProviderConfig> providers;
  final String activeId;

  AiProviderConfig? get active {
    for (final p in providers) {
      if (p.id == activeId) return p;
    }
    return providers.isNotEmpty ? providers.first : null;
  }

  bool get hasUsable => active?.isConfigured ?? false;

  AiSettings copyWith({List<AiProviderConfig>? providers, String? activeId}) {
    return AiSettings(
      providers: providers ?? this.providers,
      activeId: activeId ?? this.activeId,
    );
  }

  Map<String, dynamic> toJson() => {
        'providers': providers.map((p) => p.toJson()).toList(),
        'activeId': activeId,
      };

  factory AiSettings.fromJson(Map<String, dynamic> json) {
    final list = (json['providers'] as List<dynamic>? ?? [])
        .map((e) => AiProviderConfig.fromJson(e as Map<String, dynamic>))
        .toList();
    return AiSettings(
      providers: list,
      activeId: (json['activeId'] as String?) ?? (list.isNotEmpty ? list.first.id : ''),
    );
  }
}

/// AI 调用异常，携带用户可读信息（不含敏感数据）。
class AiException implements Exception {
  AiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// OpenAI 兼容的解卦客户端。
class AiInterpreter {
  AiInterpreter({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri _endpoint(String baseUrl) {
    var b = baseUrl.trim();
    while (b.endsWith('/')) {
      b = b.substring(0, b.length - 1);
    }
    // 若用户已带 /chat/completions 则直接用，否则补全。
    if (b.endsWith('/chat/completions')) return Uri.parse(b);
    return Uri.parse('$b/chat/completions');
  }

  /// 调用远端模型解卦，返回纯文本。
  Future<String> analyze({
    required AiProviderConfig config,
    required Reading reading,
    required Interpretation local,
  }) async {
    if (!config.isConfigured) {
      throw AiException('尚未配置供应商，请先填写接口地址与密钥。');
    }

    final payload = <String, dynamic>{
      'model': config.model,
      'temperature': config.temperature,
      'messages': [
        {'role': 'system', 'content': config.systemPrompt},
        {'role': 'user', 'content': buildPrompt(reading, local)},
      ],
    };

    http.Response resp;
    try {
      resp = await _client
          .post(
            _endpoint(config.baseUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${config.apiKey}',
            },
            body: utf8.encode(jsonEncode(payload)),
          )
          .timeout(const Duration(seconds: 90));
    } catch (e) {
      throw AiException('网络请求失败：${_safeError(e)}');
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw AiException('供应商返回错误（HTTP ${resp.statusCode}）：'
          '${_extractError(resp.body)}');
    }

    try {
      final body = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      final choices = body['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) {
        throw AiException('供应商未返回有效内容。');
      }
      final msg = (choices.first as Map<String, dynamic>)['message']
          as Map<String, dynamic>?;
      final content = msg?['content'] as String?;
      if (content == null || content.trim().isEmpty) {
        throw AiException('供应商返回内容为空。');
      }
      return content.trim();
    } on AiException {
      rethrow;
    } catch (_) {
      throw AiException('无法解析供应商响应。');
    }
  }

  /// 流式解卦：逐块产出增量文本(SSE, OpenAI 兼容)。
  Stream<String> analyzeStream({
    required AiProviderConfig config,
    required Reading reading,
    required Interpretation local,
  }) async* {
    if (!config.isConfigured) {
      throw AiException('尚未配置供应商，请先填写接口地址与密钥。');
    }

    final payload = <String, dynamic>{
      'model': config.model,
      'temperature': config.temperature,
      'stream': true,
      'messages': [
        {'role': 'system', 'content': config.systemPrompt},
        {'role': 'user', 'content': buildPrompt(reading, local)},
      ],
    };

    final request = http.Request('POST', _endpoint(config.baseUrl))
      ..headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${config.apiKey}',
        'Accept': 'text/event-stream',
      })
      ..bodyBytes = utf8.encode(jsonEncode(payload));

    http.StreamedResponse resp;
    try {
      resp = await _client.send(request).timeout(const Duration(seconds: 90));
    } catch (e) {
      throw AiException('网络请求失败：${_safeError(e)}');
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final body = await resp.stream.bytesToString();
      throw AiException('供应商返回错误（HTTP ${resp.statusCode}）：'
          '${_extractError(body)}');
    }

    var buffer = '';
    var emitted = false;
    await for (final chunk
        in resp.stream.transform(utf8.decoder)) {
      buffer += chunk;
      // SSE 以空行分隔事件；按行解析 data: 前缀。
      var idx = buffer.indexOf('\n');
      while (idx != -1) {
        final line = buffer.substring(0, idx).trimRight();
        buffer = buffer.substring(idx + 1);
        idx = buffer.indexOf('\n');
        if (!line.startsWith('data:')) continue;
        final data = line.substring(5).trim();
        if (data.isEmpty) continue;
        if (data == '[DONE]') return;
        try {
          final obj = jsonDecode(data) as Map<String, dynamic>;
          final choices = obj['choices'] as List<dynamic>?;
          if (choices == null || choices.isEmpty) continue;
          final delta =
              (choices.first as Map<String, dynamic>)['delta']
                  as Map<String, dynamic>?;
          final piece = delta?['content'] as String?;
          if (piece != null && piece.isNotEmpty) {
            emitted = true;
            yield piece;
          }
        } catch (_) {
          // 忽略无法解析的心跳/注释行。
        }
      }
    }
    if (!emitted) {
      throw AiException('供应商未返回有效内容。');
    }
  }

  /// 测试连通性（发一条极短请求）。
  Future<void> testConnection(AiProviderConfig config) async {
    if (!config.isConfigured) {
      throw AiException('请先填写接口地址与密钥。');
    }
    final payload = <String, dynamic>{
      'model': config.model,
      'messages': [
        {'role': 'user', 'content': '回复「连接正常」四个字即可。'},
      ],
      'max_tokens': 16,
    };
    http.Response resp;
    try {
      resp = await _client
          .post(
            _endpoint(config.baseUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${config.apiKey}',
            },
            body: utf8.encode(jsonEncode(payload)),
          )
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      throw AiException('网络请求失败：${_safeError(e)}');
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw AiException('HTTP ${resp.statusCode}：${_extractError(resp.body)}');
    }
  }

  String _extractError(String body) {
    try {
      final j = jsonDecode(body);
      if (j is Map && j['error'] != null) {
        final err = j['error'];
        if (err is Map && err['message'] != null) {
          return err['message'].toString();
        }
        return err.toString();
      }
    } catch (_) {}
    final trimmed = body.trim();
    return trimmed.isEmpty
        ? '（无返回内容）'
        : trimmed.substring(0, trimmed.length.clamp(0, 200));
  }

  /// 避免把可能含密钥的异常明文外泄。
  String _safeError(Object e) {
    final s = e.toString();
    return s.length > 160 ? '${s.substring(0, 160)}…' : s;
  }

  /// 将排盘数据序列化为供模型阅读的提示词。
  static String buildPrompt(Reading r, Interpretation local) {
    final b = StringBuffer();
    b.writeln('请为以下六爻排盘作解读。');
    b.writeln();
    b.writeln('【所问】${r.question}');
    b.writeln('【起卦方式】${r.method}');
    b.writeln('【干支日辰】${r.ganZhi.yearGanZhi}年 '
        '${r.ganZhi.monthZhiName}月 ${r.ganZhi.dayGanZhi}日');
    b.writeln('【旬空】${r.ganZhi.xunKongName}');
    b.writeln();
    b.writeln('【本卦】${r.primary.fullTitle}');
    b.writeln(_hexTable(r.primary, r));
    if (r.changed != null) {
      b.writeln();
      b.writeln('【变卦】${r.changed!.fullTitle}');
      b.writeln(_hexTable(r.changed!, r, changed: true));
    } else {
      b.writeln();
      b.writeln('【变卦】无（六爻安静）');
    }
    b.writeln();
    b.writeln('【程序初步要点】');
    b.writeln('· ${local.summary}');
    for (final p in local.points) {
      b.writeln('· $p');
    }
    b.writeln('· ${local.shiYingNote}');
    for (final m in local.movingNotes) {
      b.writeln('· 动爻：$m');
    }
    for (final k in local.kongWang) {
      b.writeln('· 空亡：$k');
    }
    b.writeln();
    b.writeln('请结合以上信息，给出条理清晰、平实中肯的参详。');
    return b.toString();
  }

  static String _hexTable(Hexagram h, Reading r, {bool changed = false}) {
    const names = ['初爻', '二爻', '三爻', '四爻', '五爻', '上爻'];
    final b = StringBuffer();
    // 上爻在上，初爻在下，符合排盘习惯。
    for (var pos = 5; pos >= 0; pos--) {
      final y = h.yaos[pos];
      final marks = <String>[];
      if (y.isShi) marks.add('世');
      if (y.isYing) marks.add('应');
      if (!changed && r.tosses[pos].moving) marks.add('动');
      final markStr = marks.isEmpty ? '' : '（${marks.join('')}）';
      final shen = y.liuShen?.zh ?? '';
      final line = y.yang ? '▅▅▅▅▅' : '▅▅ ▅▅';
      b.writeln('  ${names[pos]} $shen ${y.liuQin.zh} ${y.ganZhi} '
          '$line$markStr');
      if (y.hidden != null) {
        b.writeln('        伏神：${y.hidden!.liuQin.zh} ${y.hidden!.ganZhi}');
      }
    }
    return b.toString().trimRight();
  }
}
