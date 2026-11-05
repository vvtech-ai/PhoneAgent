import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/call_models/domain/call_models.dart';
import 'package:phone_agent/features/call_models/presentation/controller/call_model_controller.dart';
import 'package:phone_agent/features/call_models/presentation/pages/call_voices_page.dart';
import 'package:phone_agent/features/call_models/presentation/widgets/native_voice_selection_row.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform lzy URL or dynamic preview does not change selection',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final previews = <String>[];
        var selections = 0;
        Future<void> show({
          bool loading = false,
          bool saving = false,
          bool modelSaving = false,
          bool refresh = false,
          String url = 'https://media.invalid/lzy.wav',
        }) => tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(
              body: CallVoicesPage(
                state: CallModelState(
                  voiceProvider: '20',
                  voices: CallVoiceCatalog('lzy', 'AI', [
                    CallVoice('lzy', 'Lzy', '', true, previewAudioUrl: url),
                  ]),
                  voiceLoading: loading,
                  voiceSaving: saving,
                  saving: modelSaving,
                  cloneNeedsRefresh: refresh,
                ),
                onBack: () {},
                onRetry: () {},
                onSelect: (_) => selections++,
                onPreview: previews.add,
              ),
            ),
          ),
        );
        final button = find.bySemanticsLabel('试听Lzy');
        await show();
        expect(
          tester.getSemantics(button).hasFlag(SemanticsFlag.isEnabled),
          isTrue,
        );
        await tester.tap(button);
        expect(previews, ['lzy']);
        expect(selections, 0);
        for (final blocked in [
          () => show(loading: true),
          () => show(saving: true),
          () => show(modelSaving: true),
          () => show(refresh: true),
        ]) {
          await blocked();
          expect(
            tester.getSemantics(button).hasFlag(SemanticsFlag.isEnabled),
            isFalse,
          );
        }
        await show(url: '');
        expect(
          tester.getSemantics(button).hasFlag(SemanticsFlag.isEnabled),
          isTrue,
        );
        await tester.tap(button);
        expect(previews, ['lzy', 'lzy']);
        expect(selections, 0);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );

    testWidgets('$platform preview control does not select voice', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      var selected = 0, previews = 0;
      Future<void> show({
        bool loading = false,
        bool playing = false,
        bool enabled = true,
      }) => tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: Scaffold(
            body: SizedBox(
              width: 280,
              child: NativeVoiceSelectionRow(
                voice: const CallVoice('Andre', 'Andre', '清朗男声', true),
                selected: false,
                enabled: true,
                onSelect: () => selected++,
                showPreview: true,
                previewLoading: loading,
                previewPlaying: playing,
                onPreview: enabled ? () => previews++ : null,
              ),
            ),
          ),
        ),
      );
      await show();
      await tester.tap(find.bySemanticsLabel('试听Andre'));
      expect([selected, previews], [0, 1]);
      expect(tester.widget<Icon>(find.byIcon(Icons.play_arrow)).size, 19);
      await show(loading: true);
      expect(find.bySemanticsLabel('读取Andre试听'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await show(playing: true);
      await tester.tap(find.bySemanticsLabel('停止Andre试听'));
      expect([selected, previews], [0, 2]);
      await show(enabled: false);
      final node = tester.getSemantics(find.bySemanticsLabel('试听Andre'));
      expect(node.hasFlag(SemanticsFlag.isEnabled), isFalse);
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
      await tester.tap(find.bySemanticsLabel('试听Andre'));
      expect([selected, previews], [0, 2]);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }
}
