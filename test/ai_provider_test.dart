import 'package:flutter_test/flutter_test.dart';
import 'package:liuyao/domain/ai_provider.dart';
import 'package:liuyao/domain/casting.dart';
import 'package:liuyao/domain/interpreter.dart';
import 'package:liuyao/domain/location_context.dart';

void main() {
  test('配置 JSON 往返保持一致', () {
    const cfg = AiProviderConfig(
      baseUrl: 'https://api.deepseek.com/v1',
      apiKey: 'sk-test',
      model: 'deepseek-chat',
      temperature: 0.4,
    );
    final back = AiProviderConfig.fromJson(cfg.toJson());
    expect(back.baseUrl, cfg.baseUrl);
    expect(back.apiKey, cfg.apiKey);
    expect(back.model, cfg.model);
    expect(back.temperature, closeTo(0.4, 1e-9));
  });

  test('缺少地址或密钥则视为未配置', () {
    expect(const AiProviderConfig(apiKey: '').isConfigured, isFalse);
    expect(
      const AiProviderConfig(baseUrl: '', apiKey: 'k').isConfigured,
      isFalse,
    );
    expect(
      const AiProviderConfig(baseUrl: 'x', apiKey: 'k').isConfigured,
      isTrue,
    );
  });

  test('提示词包含问题、卦名与要点', () {
    final caster = Caster();
    final tosses = caster.fromValues([9, 7, 8, 6, 7, 8]);
    final reading = caster.castFromTosses(
      tosses: tosses,
      question: '近期事业如何',
      method: '手动排爻',
      at: DateTime(2024, 3, 15),
    );
    final interp = Interpreter().interpret(reading);
    final prompt = AiInterpreter.buildPrompt(reading, interp);

    expect(prompt, contains('近期事业如何'));
    expect(prompt, contains('本卦'));
    expect(prompt, contains(reading.primary.name));
    expect(prompt, contains('世'));
  });

  test('提示词包含位置、近期事件及过去现在未来解读协议', () {
    final caster = Caster();
    final reading = caster.castFromTosses(
      tosses: caster.fromValues([9, 7, 8, 6, 7, 8]),
      question: '近期事业如何',
      method: '手动排爻',
      at: DateTime(2026, 7, 10, 11),
      locationContext: LocationContext(
        latitude: 39.9042,
        longitude: 116.4074,
        accuracyMeters: 25,
        capturedAt: DateTime(2026, 7, 10, 10, 58),
        country: '中国',
        region: '北京市',
        district: '东城区',
        weatherSummary: '多云，29.4℃',
        recentEvents: const [
          LocationEvent(
            title: '东城区发布近期公共活动安排',
            sourceName: '京报网',
            url: 'https://example.com/local-event',
          ),
        ],
      ),
    );
    final prompt = AiInterpreter.buildPrompt(
      reading,
      Interpreter().interpret(reading),
    );

    expect(prompt, contains('北京市 · 东城区'));
    expect(prompt, contains('东城区发布近期公共活动安排'));
    expect(prompt, contains('过去印证'));
    expect(prompt, contains('现在局势'));
    expect(prompt, contains('未来演变'));
    expect(prompt, contains('绝不能推定用户本人参与其中'));
  });
}
