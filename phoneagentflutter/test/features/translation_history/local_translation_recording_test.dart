import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phone_agent/features/translation_history/presentation/controller/translation_history_controller.dart';
import 'package:phone_agent/features/translation_history/presentation/pages/translation_history_page.dart';
import 'package:phone_agent/features/translation_history/presentation/widgets/recording_audio_card.dart';
import 'package:phone_agent/features/translation_history/presentation/controller/recording_audio_controller.dart';
import 'package:phone_agent/features/translation/data/recording/domestic_recording_finalizer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/data/recording/private_domestic_recording_files.dart';
import 'package:phone_agent/features/translation/data/recording/pcm_recording_journal.dart';
import 'package:phone_agent/features/translation/domain/recording/pcm_timeline.dart';
import 'package:phone_agent/features/translation/domain/recording/domestic_recording_encoder.dart';
import 'package:phone_agent/features/translation_history/data/private_local_translation_recording.dart';
import 'package:phone_agent/features/translation_history/data/local_recording_history_repository.dart';
import 'package:phone_agent/features/translation_history/data/local_recording_audio_repository.dart';
import 'package:phone_agent/features/translation_history/domain/translation_history.dart';
import '../../support/recording_audio_fakes.dart';

TranslationHistory detail({bool remote = false, int duration = 1}) =>
    TranslationHistory(
      callId: 'server',
      route: TranslationRoute.domesticSip,
      targetName: 'Synthetic',
      phoneNumber: '',
      myLanguage: 'zh',
      peerLanguage: 'en',
      connectedAt: '',
      endedAt: '',
      durationMillis: duration,
      transcripts: const [],
      recording: remote
          ? const TranslationRecording(source: 'PHONE_AGENT')
          : null,
    );

class History implements TranslationHistoryRepository {
  bool remote = false;
  @override
  Future<TranslationHistory> load(String callId) async =>
      detail(remote: remote);
}

class Encoder implements DomesticRecordingEncoder {
  int calls = 0;
  bool fail = false;
  Completer<void>? entered, gate;
  @override
  Future<void> encode({
    required String pcmPath,
    required String m4aPath,
  }) async {
    calls++;
    if (entered?.isCompleted == false) entered!.complete();
    await gate?.future;
    if (fail) throw PlatformException(code: 'recording_encode_failed');
    await File(m4aPath).writeAsBytes([1, 2, 3]);
  }
}

void main() {
  late Directory root;
  late PrivateDomesticRecordingFiles files;
  late Encoder encoder;
  late PrivateLocalTranslationRecording local;
  var current = true;
  setUp(() async {
    current = true;
    root = await Directory.systemTemp.createTemp('local-translation-test');
    files = PrivateDomesticRecordingFiles(
      environment: 'test',
      apiBase: 'https://example.invalid',
      accountId: 'synthetic',
      root: () async => root,
      isCurrent: () => current,
    );
    encoder = Encoder();
    local = PrivateLocalTranslationRecording(files, encoder);
  });
  tearDown(() async => root.delete(recursive: true));
  Future<void> capture() async {
    final journal = await files.create('client', 0);
    journal.offer(
      RecordedPcmChunk(
        TranslationRecordingTrack.localCaller,
        0,
        Uint8List.fromList([1, 0]),
      ),
    );
    await journal.finish();
    await DomesticRecordingFinalizer(
      encoder,
    ).finalize(journal: journal, durationMillis: 1);
  }

  test(
    'exact server mapping restores complete capture, reuses verified file and cleans',
    () async {
      await capture();
      expect(await local.available('server'), false);
      await local.bind('server', 'client');
      expect(await local.available('server'), true);
      expect(await local.available('other'), false);
      final asset = await local.load(detail());
      expect(await File(asset.localPath).readAsBytes(), [1, 2, 3]);
      await local.load(detail());
      expect(encoder.calls, 1);
      await files.removeArchived('client');
      expect(await local.available('server'), false);
    },
  );
  test(
    'other account, incomplete capture and conflicting identities are refused',
    () async {
      final journal = await files.create('client', 0);
      await expectLater(local.bind('server', 'client'), throwsA(anything));
      await journal.finish();
      await local.bind('server', 'client');
      await expectLater(
        local.bind('different', 'client'),
        throwsFormatException,
      );
      final foreign = PrivateDomesticRecordingFiles(
        environment: files.environment,
        apiBase: files.apiBase,
        accountId: 'other',
        root: () async => root,
        isCurrent: () => current,
      );
      expect(
        await PrivateLocalTranslationRecording(
          foreign,
          encoder,
        ).available('server'),
        false,
      );
      current = false;
      await expectLater(local.available('server'), throwsStateError);
    },
  );
  test(
    'completed M4A survives rounded detail duration without encoding or PCM',
    () async {
      await capture();
      await local.bind('server', 'client');
      final journal = await files.recover('client');
      await journal.file.delete();
      expect(await local.available('server'), true);
      final asset = await local.load(detail(duration: 1000));
      expect(await File(asset.localPath).readAsBytes(), [1, 2, 3]);
      expect(encoder.calls, 1);
    },
  );
  test(
    'PCM preserves entry and restores media; damaged M4A keeps retry entry',
    () async {
      final journal = await files.create('client', 0);
      await journal.finish();
      await local.bind('server', 'client');
      expect(await local.available('server'), true);
      expect(encoder.calls, 0);
      await local.load(detail());
      expect(encoder.calls, 1);
      await File((await files.recording('client')).path).writeAsBytes([9]);
      expect(await local.available('server'), true);
      await expectLater(local.load(detail()), throwsFormatException);
    },
  );
  test('history joins ongoing encode even when SDK duration differs', () async {
    final journal = await files.create('client', 0);
    await journal.finish();
    await local.bind('server', 'client');
    encoder.entered = Completer<void>();
    encoder.gate = Completer<void>();
    final archive = DomesticRecordingFinalizer(
      encoder,
    ).finalize(journal: journal, durationMillis: 1000);
    await encoder.entered!.future;
    final playback = local.load(detail(duration: 1));
    encoder.gate!.complete();
    await archive;
    expect((await playback).size, 3);
    expect(encoder.calls, 1);
  });
  testWidgets(
    'encode failure keeps shared recording card and retry restores it',
    (tester) async {
      await tester.runAsync(() async {
        final journal = await files.create('client', 0);
        await journal.finish();
        await local.bind('server', 'client');
      });
      final history = LocalRecordingHistoryRepository(History(), local);
      final detailState = TranslationHistoryController(history, 'server');
      final audio = RecordingAudioController(
        repository: LocalRecordingAudioRepository(
          RecordingRepositoryFake(),
          history,
          local,
          'server',
          () => current,
        ),
        player: RecordingPlayerFake(),
        exporter: RecordingExporterFake(),
        isCurrent: () => current,
      );
      encoder.fail = true;
      await tester.runAsync(() async {
        await detailState.load();
        await audio.load();
      });
      expect(detailState.state.content!.recordingAvailable, true);
      expect(audio.state.phase, RecordingAudioPhase.failed);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TranslationHistoryPage(
              state: detailState.state,
              onClose: () {},
              onRetry: () {},
              recording: RecordingAudioCard(
                state: audio.state,
                onPrimary: audio.primary,
                onSave: audio.save,
              ),
            ),
          ),
        ),
      );
      expect(find.byType(RecordingAudioCard), findsOneWidget);
      expect(find.text('音频加载失败'), findsOneWidget);
      encoder.fail = false;
      await tester.runAsync(() async {
        await audio.primary();
      });
      expect(audio.state.phase, RecordingAudioPhase.ready);
      await tester.pumpWidget(const SizedBox());
      audio.dispose();
      detailState.dispose();
    },
  );
  test(
    'remote wins; local-only detail enables playback; closing prevents reuse',
    () async {
      await capture();
      await local.bind('server', 'client');
      final origin = History();
      final history = LocalRecordingHistoryRepository(origin, local);
      expect((await history.load('server')).localRecordingAvailable, true);
      final remote = RecordingRepositoryFake();
      final repository = LocalRecordingAudioRepository(
        remote,
        history,
        local,
        'server',
        () => current,
      );
      final asset = await repository.load(retry: false, processing: () {});
      expect(asset.size, 3);
      expect(remote.retries, isEmpty);
      origin.remote = true;
      expect((await history.load('server')).localRecordingAvailable, false);
      await repository.load(retry: true, processing: () {});
      expect(remote.retries, [true]);
      repository.close();
      await expectLater(
        repository.load(retry: false, processing: () {}),
        throwsStateError,
      );
    },
  );
}
