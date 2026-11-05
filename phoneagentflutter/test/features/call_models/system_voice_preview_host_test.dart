import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/system_voice_preview_providers.dart';
import 'package:phone_agent/features/call_models/domain/system_voice_preview.dart';
import 'package:phone_agent/features/call_models/presentation/controller/system_voice_preview_controller.dart';
import 'package:phone_agent/features/call_models/presentation/widgets/system_voice_preview_host.dart';

class _Port implements SystemVoicePreviewPort {
  Completer<void>? playback;
  Completer<Uint8List>? loading;
  int plays = 0, closes = 0;
  @override
  Future<Uint8List> load(String voiceId) async =>
      loading?.future ?? Uint8List.fromList([1]);
  @override
  Future<void> play(Uint8List bytes) async {
    plays++;
    playback = Completer<void>();
    await playback!.future;
  }

  @override
  Future<void> stop() async {
    if (playback?.isCompleted == false) playback!.complete();
  }

  @override
  Future<void> close() async {
    closes++;
    await stop();
  }
}

void main() {
  testWidgets('host stops on background and disposal; resume never autoplays', (
    tester,
  ) async {
    final port = _Port();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          systemVoicePreviewProvider.overrideWith(
            (ref, owner) =>
                SystemVoicePreviewController(port, isCurrent: () => true),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SystemVoicePreviewHost(
              builder: (state, toggle, stop) => TextButton(
                onPressed: () => toggle('Andre'),
                child: Text(state.phase.name),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('idle'));
    await tester.pumpAndSettle();
    expect(find.text('playing'), findsOneWidget);
    expect(port.plays, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(find.text('idle'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(port.plays, 1);
    await tester.tap(find.text('idle'));
    await tester.pumpAndSettle();
    expect(port.plays, 2);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(port.playback!.isCompleted, isTrue);
    expect(port.closes, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'switching model invalidates old asset before provider disposal',
    (tester) async {
      final model = ValueNotifier('QWEN_OMNI_PLUS');
      addTearDown(model.dispose);
      final first = _Port()..loading = Completer<Uint8List>();
      final second = _Port();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            systemVoicePreviewProvider.overrideWith(
              (ref, owner) => SystemVoicePreviewController(
                owner.modelId == 'QWEN_OMNI_PLUS' ? first : second,
                isCurrent: () => true,
              ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ValueListenableBuilder<String>(
                valueListenable: model,
                builder: (_, id, __) => SystemVoicePreviewHost(
                  modelId: id,
                  builder: (state, toggle, stop) => TextButton(
                    onPressed: () => toggle('Andre'),
                    child: Text(state.phase.name),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('idle'));
      await tester.pumpAndSettle();
      expect(find.text('loading'), findsOneWidget);
      model.value = 'DOUBAO_SEEDUPLEX_3_0';
      await tester.pump();
      first.loading!.complete(Uint8List.fromList([1]));
      await tester.pumpAndSettle();
      expect(first.plays, 0);
      expect(first.closes, 1);
      expect(find.text('idle'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(second.closes, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
