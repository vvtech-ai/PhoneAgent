import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/call_models/domain/call_models.dart';
import 'package:phone_agent/features/call_models/presentation/controller/call_model_controller.dart';
import 'package:phone_agent/features/call_models/presentation/pages/call_voices_page.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final voice in [
      const CallVoice('Lzy', 'Lzy', '男 · IndexTTS 2.5 预置男声', true),
      const CallVoice('longanqian_31', '龙安千3.1', 'Qwen Audio 3.1', true),
    ]) {
      testWidgets(
        '$platform server voice ${voice.id} can preview without selection',
        (tester) async {
          final requests = <String>[];
          var selections = 0;
          final semantics = tester.ensureSemantics();
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              home: Scaffold(
                body: CallVoicesPage(
                  state: CallModelState(
                    voiceProvider: 'catalog-model',
                    voices: CallVoiceCatalog(voice.id, 'AI', [voice]),
                  ),
                  onBack: () {},
                  onRetry: () {},
                  onSelect: (_) => selections++,
                  onPreview: requests.add,
                ),
              ),
            ),
          );
          final preview = find.bySemanticsLabel('试听${voice.name}');
          await tester.ensureVisible(preview);
          await tester.tap(preview);
          expect(requests, [voice.id]);
          expect(selections, 0);
          semantics.dispose();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
