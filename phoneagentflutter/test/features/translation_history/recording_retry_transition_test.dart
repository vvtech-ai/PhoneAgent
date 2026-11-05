import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/receipts/call_recording_control.dart';
import 'package:phone_agent/features/translation_history/presentation/controller/recording_audio_controller.dart';
import 'package:phone_agent/features/translation_history/presentation/widgets/native_recording_waveform.dart';
import '../../support/recording_audio_fakes.dart';

void main() {
  for (final ordinary in [false, true]) {
    testWidgets('retry keeps compact card and existing playback $ordinary', (
      tester,
    ) async {
      final repository = RecordingRepositoryFake()..fail = true;
      final player = RecordingPlayerFake();
      final exporter = RecordingExporterFake();
      final controller = RecordingAudioController(
        repository: repository,
        player: player,
        exporter: exporter,
        isCurrent: () => true,
        loadOnAction: ordinary,
      );
      addTearDown(controller.dispose);
      await controller.load();
      repository
        ..fail = false
        ..pending = Completer();
      final retry = controller.primary();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 393,
                child: CallRecordingControl(
                  state: controller.state,
                  compact: false,
                  saving: false,
                  onPrimary: () => unawaited(controller.primary()),
                  onSave: () => unawaited(controller.save()),
                ),
              ),
            ),
          ),
        ),
      );
      expect(controller.state.retrying, isTrue);
      expect(controller.state.busy, isTrue);
      expect(find.text('音频加载失败'), findsOneWidget);
      expect(find.text('录音加载中'), findsNothing);
      final waveform = find.byType(NativeRecordingWaveform);
      expect(tester.getSize(waveform).height, 30);
      final primary = tester.widget<IconButton>(
        find.byKey(const ValueKey('recording-primary')),
      );
      expect(primary.tooltip, '音频加载失败');
      expect(primary.onPressed, isNull);
      final save = find.byKey(const ValueKey('recording-save'));
      expect(tester.widget<IconButton>(save).onPressed, isNotNull);
      expect(
        find.descendant(
          of: save,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
      );
      await controller.primary();
      await tester.tap(save);
      await tester.pump();
      expect(exporter.saves, 0);
      expect(repository.retries, [false, true]);
      expect(controller.state.retrying, isTrue);
      repository.pending!.complete(recordingAsset);
      await retry;
      expect(controller.state.retrying, isFalse);
      expect(
        controller.state.phase,
        ordinary ? RecordingAudioPhase.playing : RecordingAudioPhase.ready,
      );
      expect(player.plays, ordinary ? 1 : 0);
      if (!ordinary) {
        await controller.primary();
        expect(player.plays, 1);
      }
      expect(tester.takeException(), isNull);
    });
  }

  test('processing and another failure clear retry presentation', () async {
    final repository = RecordingRepositoryFake()..fail = true;
    final controller = RecordingAudioController(
      repository: repository,
      player: RecordingPlayerFake(),
      exporter: RecordingExporterFake(),
      isCurrent: () => true,
    );
    addTearDown(controller.dispose);
    await controller.load();
    repository.waiting = true;
    final phases = <RecordingAudioState>[];
    final unsubscribe = controller.addListener(
      phases.add,
      fireImmediately: false,
    );
    await controller.primary();
    unsubscribe();
    expect(phases.first.retrying, isTrue);
    expect(
      phases.any(
        (s) => s.phase == RecordingAudioPhase.processing && !s.retrying,
      ),
      isTrue,
    );
    expect(controller.state.phase, RecordingAudioPhase.failed);
    expect(controller.state.retrying, isFalse);
  });

  test(
    'interruption invalidates pending retry and clears its presentation',
    () async {
      final repository = RecordingRepositoryFake()..fail = true;
      final player = RecordingPlayerFake();
      final controller = RecordingAudioController(
        repository: repository,
        player: player,
        exporter: RecordingExporterFake(),
        isCurrent: () => true,
      );
      addTearDown(controller.dispose);
      await controller.load();
      repository
        ..fail = false
        ..pending = Completer();
      final retry = controller.primary();
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.retrying, isTrue);
      await controller.interruptPlayback();
      expect(controller.state.phase, RecordingAudioPhase.idle);
      expect(controller.state.retrying, isFalse);
      repository.pending!.complete(recordingAsset);
      await retry;
      expect(controller.state.phase, RecordingAudioPhase.idle);
      expect(player.prepares, 0);
      expect(player.plays, 0);
    },
  );
}
