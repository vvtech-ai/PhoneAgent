import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/call_models/domain/clone_voice.dart';
import 'package:phone_agent/features/call_models/domain/system_voice_preview.dart';
import 'package:phone_agent/features/call_models/presentation/controller/call_model_controller.dart';
import 'package:phone_agent/features/call_models/presentation/pages/call_voices_page.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform preview targets ready candidate before current and never confirms',
      (tester) async {
        final handle = tester.ensureSemantics();
        final requests = <String>[];
        var confirmations = 0;
        Future<void> show({
          bool candidate = false,
          bool busy = false,
          String model = 'QWEN_OMNI_PLUS',
        }) => tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(
              body: CallVoicesPage(
                state: CallModelState(
                  voiceProvider: 'QWEN_OMNI_PLUS',
                  cloneLoading: busy,
                  clone: CloneVoiceSnapshot(
                    modelId: model,
                    available: true,
                    currentStatus: 'READY',
                    currentHasAsset: true,
                    candidateStatus: candidate ? 'READY' : '',
                    candidateBillingStatus: candidate ? 'CHARGED' : '',
                  ),
                ),
                onBack: () {},
                onRetry: () {},
                onSelect: (_) {},
                onSelectClone: () => confirmations++,
                onPreview: requests.add,
              ),
            ),
          ),
        );
        await show();
        await tester.tap(find.bySemanticsLabel('试听我的克隆音色'));
        expect(requests, [cloneCurrentPreviewId]);
        await show(candidate: true);
        await tester.tap(find.bySemanticsLabel('试听新克隆音色'));
        expect(requests, [cloneCurrentPreviewId, cloneCandidatePreviewId]);
        expect(confirmations, 0);
        await show(busy: true);
        await tester.tap(find.bySemanticsLabel('试听我的克隆音色'));
        await show(model: 'DOUBAO_SEEDUPLEX_3_0');
        await tester.tap(find.bySemanticsLabel('试听我的克隆音色'));
        expect(requests, hasLength(2));
        expect(confirmations, 0);
        handle.dispose();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
