import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/settings/presentation/widgets/settings_model_summary.dart';

void main() {
  test(
    'native model prefixes preserve complete characters and trim separators',
    () {
      expect(settingsModelSummary(' QwenOmniPlus ', 1), 'QwenOmni… ×1.0');
      expect(settingsModelSummary('Doubao realtime', 1.25), 'Doubao… ×1.3');
      expect(settingsModelSummary('千问实时语音模型', 2), '千问实时… ×2.0');
      expect(settingsModelSummary('😀合成模型名称', null), '😀合成模…');
      expect(settingsModelSummary('  ', 2), '');
    },
  );
  test(
    'missing and invalid model prices are never presented as billable rates',
    () {
      for (final price in [null, double.nan, double.infinity, -1.0, 0.0]) {
        expect(settingsModelSummary('合成模型', price), '合成模型…');
      }
    },
  );
}
