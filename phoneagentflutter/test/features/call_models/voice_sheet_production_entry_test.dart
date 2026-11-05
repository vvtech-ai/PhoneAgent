import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/call_models/domain/call_models.dart';
import 'package:phone_agent/features/call_models/domain/clone_voice.dart';
import 'package:phone_agent/features/call_models/presentation/controller/call_model_controller.dart';
import 'package:phone_agent/features/call_models/presentation/pages/call_voices_page.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      for (final ready in [false, true]) {
        testWidgets(
          '$platform production voices exclude mock ready=$ready scale=$scale',
          (tester) async {
            tester.view.physicalSize = const Size(390, 780);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            var creates = 0, selects = 0;
            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(platform: platform),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Scaffold(
                  body: CallVoicesPage(
                    state: CallModelState(
                      voiceProvider: 'QWEN_OMNI_PLUS',
                      voices: const CallVoiceCatalog('Andre', 'AI', [
                        CallVoice('Andre', 'Andre', '系统音色', true),
                      ]),
                      clone: CloneVoiceSnapshot(
                        modelId: 'QWEN_OMNI_PLUS',
                        available: true,
                        currentStatus: ready ? 'READY' : 'NOT_CREATED',
                        currentHasAsset: ready,
                      ),
                    ),
                    onBack: () {},
                    onRetry: () {},
                    onSelect: (_) {},
                    onSelectClone: () => selects++,
                    onCreateClone: () => creates++,
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.textContaining('MOCK'), findsNothing);
            expect(find.textContaining('交互演练'), findsNothing);
            final action = ready
                ? find.byKey(const ValueKey('selectCloneVoice'))
                : find.byKey(const ValueKey('voice-create-clone'));
            await tester.ensureVisible(action);
            await tester.pumpAndSettle();
            await tester.tap(action);
            await tester.pumpAndSettle();
            expect(creates, ready ? 0 : 1);
            expect(selects, ready ? 1 : 0);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
