import 'translation_directory.dart';

String translationDialPricingText(TranslationDirectoryModel? model) {
  final first = model?.firstMinutePoints;
  final block = model?.sixSecondPoints;
  final seconds = model?.blockSeconds;
  final period = model?.firstPeriodMs;
  if (first == null ||
      first <= 0 ||
      block == null ||
      block <= 0 ||
      seconds == null ||
      seconds < 1 ||
      seconds > 3600 ||
      period == null ||
      period < 1000 ||
      period > 3600000) {
    return '积分按接通时的模型价格计算 · 未接通不扣';
  }
  final firstLabel = period == 60000
      ? '首分钟'
      : period % 1000 == 0
      ? '前 ${period ~/ 1000} 秒'
      : '前 $period 毫秒';
  final note = model?.multiplier != null ? '模型倍率已计入' : '当前报价';
  return '接通后$firstLabel ✦$first，之后每 $seconds 秒 ✦$block\n$note · 未接通不扣';
}
