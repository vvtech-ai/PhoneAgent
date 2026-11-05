import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/recording_providers.dart';
import 'package:phone_agent/app/translation_history_providers.dart';
import 'package:phone_agent/features/translation_history/domain/translation_history.dart';
import 'package:phone_agent/features/translation_history/presentation/controller/recording_audio_controller.dart';
import 'package:phone_agent/features/translation_history/presentation/pages/translation_history_route.dart';
import '../../support/recording_audio_fakes.dart';

void main() {
  late RecordingRepositoryFake recording;
  late RecordingPlayerFake player;
  late RecordingExporterFake exporter;
  late _History history;
  var mounted = 0;
  setUp(() {
    recording = RecordingRepositoryFake();
    player = RecordingPlayerFake();
    exporter = RecordingExporterFake();
    history = _History();
    mounted = 0;
  });
  Future<void> open(WidgetTester tester, {bool supported = true}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recordingSupportedProvider.overrideWithValue(supported),
          translationHistoryRepositoryProvider.overrideWithValue(history),
          recordingAudioControllerProvider.overrideWith((ref, id) {
            expect(id, 'synthetic-call');
            mounted++;
            final controller = RecordingAudioController(
              repository: recording,
              player: player,
              exporter: exporter,
              isCurrent: () => true,
            );
            controller.load();
            return controller;
          }),
        ],
        child: const MaterialApp(
          home: TranslationHistoryRoute(callId: 'synthetic-call'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'formal route mounts audio only after recording metadata, never auto plays',
    (tester) async {
      await open(tester);
      expect(mounted, 1);
      expect(player.prepares, 1);
      expect(player.plays, 0);
      expect(find.text('合成字幕'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('recording-primary')));
      await tester.pumpAndSettle();
      expect(player.plays, 1);
      await tester.tap(find.byKey(const ValueKey('recording-primary')));
      await tester.pumpAndSettle();
      expect(player.pauses, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(player.closed, true);
      expect(recording.closed, true);
      expect(exporter.closed, true);
    },
  );
  testWidgets(
    'local fallback mounts native recording without remote metadata',
    (tester) async {
      history.recording = false;
      history.local = true;
      await open(tester);
      expect(mounted, 1);
      expect(find.text('通话录音'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('translation-recording-scrim')),
        findsOneWidget,
      );
      expect(player.plays, 0);
    },
  );
  testWidgets('missing metadata never creates audio resources', (tester) async {
    history.recording = false;
    await open(tester);
    expect(mounted, 0);
    expect(find.byKey(const ValueKey('recording-primary')), findsNothing);
    expect(find.text('合成字幕'), findsOneWidget);
  });
  testWidgets('unsupported Web boundary never creates a native controller', (
    tester,
  ) async {
    await open(tester, supported: false);
    expect(mounted, 0);
    expect(find.textContaining('Web 可在开发者演练'), findsOneWidget);
    expect(find.text('合成字幕'), findsOneWidget);
  });
  testWidgets('failed audio keeps subtitle and retries in same formal page', (
    tester,
  ) async {
    recording.fail = true;
    await open(tester);
    expect(find.text('合成字幕'), findsOneWidget);
    expect(find.byTooltip('重试加载录音'), findsOneWidget);
    recording.fail = false;
    await tester.tap(find.byKey(const ValueKey('recording-primary')));
    await tester.pumpAndSettle();
    expect(recording.retries, [false, true]);
    expect(mounted, 1);
    expect(find.byTooltip('播放录音'), findsOneWidget);
  });
}

class _History implements TranslationHistoryRepository {
  bool recording = true;
  bool local = false;
  @override
  Future<TranslationHistory> load(String callId) async => TranslationHistory(
    callId: callId,
    route: TranslationRoute.worldCall,
    targetName: '合成对象',
    phoneNumber: '',
    myLanguage: 'zh',
    peerLanguage: 'en',
    connectedAt: '',
    endedAt: '',
    durationMillis: 12000,
    transcripts: const [
      TranslationTranscript(
        segmentId: '1',
        sourceLeg: 'user',
        sourceLanguage: 'zh',
        sourceText: '合成字幕',
        translatedLanguage: 'en',
        translatedText: 'Synthetic subtitle',
        isFinal: true,
      ),
    ],
    localRecordingAvailable: local,
    recording: recording
        ? const TranslationRecording(source: 'WORLD_CALL')
        : null,
  );
}
