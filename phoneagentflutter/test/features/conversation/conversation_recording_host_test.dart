import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/call_recording_providers.dart';
import 'package:phone_agent/app/recording_providers.dart';
import 'package:phone_agent/features/conversation/domain/call_recording.dart';
import 'package:phone_agent/features/conversation/domain/call_recording_save.dart';
import 'package:phone_agent/features/conversation/presentation/controller/call_recording_metadata_observer.dart';
import 'package:phone_agent/features/conversation/presentation/controller/call_recording_playback_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/call_recording_save_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_recordings_controller.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/receipts/conversation_recording_host.dart';
import 'package:phone_agent/features/translation_history/domain/recording_audio.dart';
import 'package:phone_agent/features/translation_history/presentation/controller/recording_audio_controller.dart';
import '../../support/recording_audio_fakes.dart';
import 'package:phone_agent/features/translation_history/presentation/widgets/native_recording_waveform.dart';

const _nativeIdleLevels = <double>[
  .35,
  .72,
  .92,
  .48,
  .82,
  .60,
  .96,
  .52,
  .76,
  .40,
  .88,
  .66,
  1,
  .54,
  .84,
  .44,
  .90,
  .62,
  .78,
  .38,
  .86,
  .56,
  .94,
  .70,
];

void main() {
  late _Host ports;
  late ProviderContainer container;
  setUp(() {
    ports = _Host();
    container = ProviderContainer(
      overrides: [
        recordingSupportedProvider.overrideWithValue(true),
        accountApiProvider.overrideWith(
          (ref) => throw StateError('No real account access'),
        ),
        conversationRecordingsProvider.overrideWith((ref, host) {
          final manager = ports.manager;
          ref.onDispose(manager.dispose);
          return manager;
        }),
      ],
    );
  });
  tearDown(() {
    container.dispose();
    ports.manager.dispose();
  });
  Widget view({bool show = true, bool voice = false}) =>
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: ConversationRecordingHost(
              voiceMode: voice,
              builder: (recording) =>
                  Column(children: [if (show) recording('call-1', false)]),
            ),
          ),
        ),
      );
  testWidgets(
    'formal host mounts metadata only, retains playback offscreen and stops on exit',
    (tester) async {
      await tester.pumpWidget(view());
      await tester.pumpAndSettle();
      expect(ports.repository.reads, 1);
      expect(ports.repository.retries, isEmpty);
      await tester.tap(find.byKey(const ValueKey('recording-primary')));
      await tester.pumpAndSettle();
      expect(ports.player.plays, 1);
      await tester.pumpWidget(view(show: false));
      await tester.pump();
      expect(ports.player.closed, false);
      expect(ports.entry.audio.state.phase, RecordingAudioPhase.playing);
      await tester.pumpWidget(view());
      await tester.pumpAndSettle();
      expect(ports.created, 1);
      expect(ports.repository.reads, 2);
      expect(find.byTooltip('暂停录音'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(ports.player.closed, true);
      expect(ports.repository.closed, true);
      expect(ports.destination.closed, true);
    },
  );
  testWidgets(
    'actual player samples reach recording bars and pause preserves the last frame',
    (tester) async {
      await tester.pumpWidget(view());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('recording-primary')));
      await tester.pumpAndSettle();
      final levels = List.generate(24, (i) => .12 + i / 30);
      ports.player.stream.add(
        RecordingPlaybackEvent(waveform: levels, positionMillis: 3000),
      );
      await tester.pump();
      final wave = find.byType(NativeRecordingWaveform);
      expect(tester.widget<NativeRecordingWaveform>(wave).levels, levels);
      expect(find.text('00:09'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.widget<NativeRecordingWaveform>(wave).levels, levels);
      await tester.tap(find.byKey(const ValueKey('recording-primary')));
      await tester.pumpAndSettle();
      expect(tester.widget<NativeRecordingWaveform>(wave).levels, levels);
      await tester.tap(find.byKey(const ValueKey('recording-primary')));
      await tester.pumpAndSettle();
      ports.player.stream.add(const RecordingPlaybackEvent(completed: true));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NativeRecordingWaveform>(wave).levels,
        _nativeIdleLevels,
      );
      expect(ports.entry.audio.state.phase, RecordingAudioPhase.idle);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
  testWidgets(
    'background stops playing and metadata resumes only on foreground',
    (tester) async {
      await tester.pumpWidget(view());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('recording-primary')));
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      expect(ports.entry.audio.state.phase, RecordingAudioPhase.idle);
      final reads = ports.repository.reads;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(ports.repository.reads, reads + 1);
      expect(ports.player.plays, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
  testWidgets('switch to voice and call overlay stops existing playback', (
    tester,
  ) async {
    await tester.pumpWidget(view());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('recording-primary')));
    await tester.pumpAndSettle();
    await tester.pumpWidget(view(voice: true));
    await tester.pumpAndSettle();
    expect(ports.entry.audio.state.phase, RecordingAudioPhase.idle);
    await ports.entry.playback.primary();
    ports.manager.setVisible(false);
    await tester.pumpAndSettle();
    expect(ports.entry.audio.state.phase, RecordingAudioPhase.idle);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
  testWidgets(
    'ordinary save takes a fresh source independently, failed save leaves playback running',
    (tester) async {
      await tester.pumpWidget(view());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('recording-primary')));
      await tester.pumpAndSettle();
      ports.destination.fail = true;
      await tester.tap(find.byKey(const ValueKey('recording-save')));
      await tester.pumpAndSettle();
      expect(ports.repository.retries, [false, true]);
      expect(ports.entry.audio.state.phase, RecordingAudioPhase.playing);
      expect(find.text('录音保存失败，请重试'), findsOneWidget);
      expect(ports.player.plays, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
  testWidgets(
    'same call in a replacement host cannot inherit paused waveform',
    (tester) async {
      await tester.pumpWidget(view());
      await tester.pumpAndSettle();
      await ports.entry.playback.primary();
      final levels = List.generate(24, (i) => .2 + i / 40);
      ports.player.stream.add(RecordingPlaybackEvent(waveform: levels));
      await tester.pump();
      await ports.entry.playback.primary();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<NativeRecordingWaveform>(
              find.byType(NativeRecordingWaveform),
            )
            .levels,
        levels,
      );
      final next = _Host();
      final entry = next.manager.attach('call-1');
      await entry.playback.primary();
      await entry.playback.primary();
      ports = next;
      container.invalidate(conversationRecordingsProvider);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<NativeRecordingWaveform>(
              find.byType(NativeRecordingWaveform),
            )
            .levels,
        _nativeIdleLevels,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets('new account scope disposes old ports and mounts new state', (
    tester,
  ) async {
    await tester.pumpWidget(view());
    await tester.pumpAndSettle();
    final old = ports;
    ports = _Host();
    container.invalidate(conversationRecordingsProvider);
    await tester.pumpAndSettle();
    expect(old.player.closed, true);
    expect(old.destination.closed, true);
    expect(ports.created, 1);
    expect(ports.repository.retries, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
  testWidgets(
    'unsupported Web boundary never constructs account or native ports',
    (tester) async {
      container.dispose();
      container = ProviderContainer(
        overrides: [
          recordingSupportedProvider.overrideWithValue(false),
          conversationRecordingsProvider.overrideWith(
            (ref, host) => throw StateError('No native ports'),
          ),
        ],
      );
      await tester.pumpWidget(view());
      await tester.pumpAndSettle();
      expect(find.textContaining('Web 可使用隔离演练'), findsOneWidget);
      expect(ports.created, 0);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}

class _Host {
  late final manager = ConversationRecordingsController((callId, arbiter) {
    created++;
    final audio = RecordingAudioController(
      repository: repository,
      player: player,
      exporter: RecordingExporterFake(),
      isCurrent: () => true,
      loadOnAction: true,
      refreshAfterCompletion: true,
    );
    entry = ConversationRecordingEntry(
      playback: CallRecordingPlaybackController(audio: audio, arbiter: arbiter),
      metadata: CallRecordingMetadataObserver(
        repository: repository,
        onMetadata: (info) => audio.updateLogicalDuration(info.durationMillis),
        isCurrent: () => true,
      ),
      save: CallRecordingSaveController(
        SaveCallRecording(
          repository: repository,
          download: _Download(),
          destination: destination,
          fileName: 'sample.m4a',
          isCurrent: () => true,
        ),
        isCurrent: () => true,
      ),
    );
    return entry;
  });
  final repository = _Repository();
  final player = RecordingPlayerFake();
  final destination = _Destination();
  late ConversationRecordingEntry entry;
  int created = 0;
}

class _Repository extends RecordingRepositoryFake
    implements CallRecordingRepository {
  int reads = 0;
  @override
  Future<CallRecordingInfo> metadata() async {
    reads++;
    return const CallRecordingInfo(
      callId: 'call-1',
      status: 'READY',
      durationMillis: 12000,
    );
  }
}

class _Download implements CallRecordingDownload {
  @override
  Future<RecordingAudioAsset> download(RecordingAudioAsset source) async =>
      recordingAsset;
  @override
  Future<void> remove(RecordingAudioAsset asset) async {}
  @override
  void close() {}
}

class _Destination implements CallRecordingDestination {
  bool closed = false, fail = false;
  @override
  Future<bool> reserve(String fileName) async => true;
  @override
  Future<bool> write(RecordingAudioAsset asset) async {
    if (fail) throw StateError('synthetic failure');
    return true;
  }

  @override
  Future<void> abort() async {}
  @override
  Future<void> close() async => closed = true;
}
