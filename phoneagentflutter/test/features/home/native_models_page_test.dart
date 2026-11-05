import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_agent/app/task_voice_settings_providers.dart';
import 'package:phone_agent/features/settings/domain/task_voice.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/call_models/domain/call_models.dart';
import 'package:phone_agent/features/call_models/presentation/controller/call_model_controller.dart';
import 'package:phone_agent/features/call_models/presentation/pages/call_models_page.dart';

class _VoiceStore implements TaskVoiceStore {
  @override
  Future<TaskVoice> read() async => TaskVoice.maia;
  @override
  Future<void> write(TaskVoice voice) async {}
}

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform model busy, disabled and narrow large text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var selections = 0, voices = 0, clones = 0;
      const catalog = CallModelCatalog('QWEN_OMNI_PLUS', [
        CallModel(
          id: 'QWEN_OMNI_PLUS',
          name: 'QwenOmniPlus',
          description: '当前模型描述',
          available: true,
          active: true,
          multiplier: 1,
        ),
        CallModel(
          id: 'DOUBAO',
          name: 'Seeduplex',
          description: '新的模型描述',
          available: true,
          active: false,
          multiplier: 2,
        ),
        CallModel(
          id: 'unavailable',
          name: '未开放模型',
          description: '',
          available: false,
          active: false,
          status: '暂不可用',
        ),
      ]);
      Future<void> show({bool busy = false, bool sheet = false}) =>
          tester.pumpWidget(
            ProviderScope(
              overrides: [
                taskVoiceStoreProvider.overrideWithValue(_VoiceStore()),
              ],
              child: MaterialApp(
                theme: ThemeData(platform: platform),
                home: Scaffold(
                  body: MediaQuery(
                    data: const MediaQueryData(
                      size: Size(320, 740),
                      textScaler: TextScaler.linear(2),
                    ),
                    child: CallModelsPage(
                      state: CallModelState(catalog: catalog, saving: busy),
                      sheet: sheet,
                      onBack: () {},
                      onRetry: () {},
                      onSelect: (_) => selections++,
                      onVoices: (_) => voices++,
                      onCreateClone: () => clones++,
                    ),
                  ),
                ),
              ),
            ),
          );
      Future<void> tap(String key) async {
        final target = find.byKey(ValueKey(key));
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        await tester.tap(target);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      await show();
      expect(find.text('×1.0'), findsOneWidget);
      await tap('model-create-clone');
      expect(clones, 1);
      await tap('model-QWEN_OMNI_PLUS');
      expect(selections, 0);
      await tap('model-DOUBAO');
      expect(selections, 1);
      await tap('voices-DOUBAO');
      expect(voices, 1);
      await tap('model-unavailable');
      expect(selections, 1);
      await show(busy: true);
      await tester.pump();
      final tile = tester.widget<InkWell>(
        find.byKey(const ValueKey('model-DOUBAO')),
      );
      expect(tile.onTap, isNull);
      await show(sheet: true);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('model-create-clone')), findsNothing);
      expect(find.byKey(const ValueKey('voices-DOUBAO')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
