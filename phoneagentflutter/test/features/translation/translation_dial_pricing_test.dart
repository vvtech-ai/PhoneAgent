import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/domain/translation_directory.dart';
import 'package:phone_agent/features/translation/domain/translation_dial_pricing.dart';

TranslationDirectoryModel model({
  int? first = 150,
  int? block = 15,
  int? seconds = 6,
  int? period = 60000,
  double? multiplier = 1.5,
}) => TranslationDirectoryModel(
  id: 'synthetic',
  name: '合成模型',
  transport: 'LOCAL_SIP',
  provider: 'synthetic',
  subtitle: '',
  recommended: false,
  sourceLanguages: const [],
  targetLanguages: const [],
  sourceCodes: const {},
  targetCodes: const {},
  firstMinutePoints: first,
  sixSecondPoints: block,
  blockSeconds: seconds,
  firstPeriodMs: period,
  multiplier: multiplier,
);

void main() {
  const fallback = '积分按接通时的模型价格计算 · 未接通不扣';
  test('uses directory quote without applying multiplier twice', () {
    expect(
      translationDialPricingText(model()),
      '接通后首分钟 ✦150，之后每 6 秒 ✦15\n模型倍率已计入 · 未接通不扣',
    );
  });
  test('supports configured first period and billing block', () {
    expect(
      translationDialPricingText(
        model(period: 30000, seconds: 10, multiplier: null),
      ),
      '接通后前 30 秒 ✦150，之后每 10 秒 ✦15\n当前报价 · 未接通不扣',
    );
    expect(
      translationDialPricingText(model(period: 1500)),
      contains('前 1500 毫秒'),
    );
  });
  test('missing quote uses old app fallback without guessing price', () {
    for (final value in [
      null,
      model(first: null),
      model(block: null),
      model(seconds: null),
      model(period: null),
    ]) {
      expect(translationDialPricingText(value), fallback);
    }
  });
  test('invalid quote follows old app valid ranges', () {
    for (final value in [
      model(first: 0),
      model(block: -1),
      model(seconds: 0),
      model(seconds: 3601),
      model(period: 999),
      model(period: 3600001),
    ]) {
      expect(translationDialPricingText(value), fallback);
    }
  });
}
