import 'package:flutter_test/flutter_test.dart';
import 'package:liuyao/domain/ai_provider.dart';
import 'package:liuyao/domain/casting.dart';
import 'package:liuyao/domain/interpreter.dart';

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
    expect(const AiProviderConfig(baseUrl: '', apiKey: 'k').isConfigured,
        isFalse);
    expect(const AiProviderConfig(baseUrl: 'x', apiKey: 'k').isConfigured,
        isTrue);
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
}
