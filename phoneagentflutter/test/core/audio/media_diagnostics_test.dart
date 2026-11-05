import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/audio/diagnosed_pcm_capture.dart';
import 'package:phone_agent/core/audio/diagnosed_pcm_output.dart';
import 'package:phone_agent/core/audio/pcm_output.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_journal.dart';
import 'package:phone_agent/core/diagnostics/media_diagnostics.dart';
import 'package:phone_agent/features/app_logs/data/zip_log_repository.dart';
import 'pcm_capture_fake.dart';
import 'pcm_output_fake.dart';

void main() {
  test(
    'PCM capture logs first frame only, returns same bytes and retries stop',
    () async {
      final events = <DiagnosticEvent>[];
      final source = PcmCaptureFake();
      final capture = DiagnosedPcmCapture(
        source,
        MediaDiagnostics(events.add, DiagnosticMediaComponent.pcmCapture),
      );
      await capture.start();
      for (var i = 0; i < 100; i++) {
        final bytes = Uint8List.fromList([99, 123]);
        final pending = capture.read();
        source.frame(bytes);
        expect(await pending, same(bytes));
      }
      expect(events.length, 3);
      final end = capture.read();
      source.frame(null);
      expect(await end, isNull);
      source.failStop = true;
      await expectLater(capture.stop(), throwsException);
      expect(events.last.result, DiagnosticResult.failed);
      source.failStop = false;
      await capture.stop();
      expect(events.last.result, DiagnosticResult.succeeded);
      expect(source.stops, 2);
    },
  );

  test(
    'play diagnostic waits for actual completion and is not per chunk',
    () async {
      final events = <DiagnosticEvent>[];
      final source = PcmOutputFake();
      final output = DiagnosedPcmOutput(
        source,
        MediaDiagnostics(events.add, DiagnosticMediaComponent.pcmOutput),
      );
      await output.start(24000);
      final bytes = Uint8List(32);
      final first = output.play(bytes);
      expect(source.chunks.single, same(bytes));
      expect(events.length, 2);
      source.consume();
      await first;
      final second = output.play(bytes);
      source.consume();
      await second;
      expect(events.length, 3);
      expect(events.last.media!.stage, DiagnosticMediaStage.play);
      source.failStop = true;
      await expectLater(output.stop(), throwsStateError);
      source.failStop = false;
      await output.stop();
      expect(events.map((e) => e.result).toList().sublist(3), [
        DiagnosticResult.started,
        DiagnosticResult.failed,
        DiagnosticResult.started,
        DiagnosticResult.succeeded,
      ]);
    },
  );

  test(
    'PCM exceptions are preserved and cancellation is not device failure',
    () async {
      final events = <DiagnosticEvent>[];
      final source = PcmOutputFake();
      final output = DiagnosedPcmOutput(
        source,
        MediaDiagnostics(events.add, DiagnosticMediaComponent.pcmOutput),
      );
      await output.start(24000);
      final error = const PcmOutputFailure('output_cancelled');
      final pending = output.play(Uint8List(2));
      final assertion = expectLater(pending, throwsA(same(error)));
      source.pending.single.completeError(error);
      await assertion;
      expect(events.last.result, DiagnosticResult.cancelled);
      expect(events.last.media!.reason, isNull);
    },
  );

  test(
    'capture read error remains the original object and logs once',
    () async {
      final events = <DiagnosticEvent>[];
      final source = PcmCaptureFake();
      final capture = DiagnosedPcmCapture(
        source,
        MediaDiagnostics(events.add, DiagnosticMediaComponent.pcmCapture),
      );
      final error = StateError('private microphone detail');
      for (var i = 0; i < 2; i++) {
        final assertion = expectLater(capture.read(), throwsA(same(error)));
        source.pendingRead!.completeError(error);
        await assertion;
      }
      expect(events.length, 1);
      expect(jsonEncode(events.single.toJson()), isNot(contains('private')));
    },
  );

  test(
    'throwing diagnostics cannot change start, play, stop or original failures',
    () async {
      final source = PcmOutputFake();
      final output = DiagnosedPcmOutput(
        source,
        MediaDiagnostics(
          (_) => throw StateError('sink'),
          DiagnosticMediaComponent.pcmOutput,
        ),
      );
      await output.start(24000);
      final play = output.play(Uint8List(2));
      source.consume();
      await play;
      await output.stop();
      source.failStart = true;
      await expectLater(output.start(24000), throwsStateError);
    },
  );

  test(
    'unknown fields and old events survive journal reload and real ZIP safely',
    () async {
      final store = _Store();
      final journal = DiagnosticJournal(store);
      addTearDown(journal.close);
      final old = DiagnosticEvent(
        operation: DiagnosticOperation.accountRequest,
        result: DiagnosticResult.succeeded,
      );
      expect(DiagnosticEvent.fromJson(old.toJson()).media, isNull);
      journal.record(old);
      final json = DiagnosticEvent(
        operation: DiagnosticOperation.voiceMedia,
        result: DiagnosticResult.failed,
      ).toJson();
      json['media'] = {
        'component': 'private-url',
        'stage': 'secret-transcript',
        'reason': 'raw-exception',
        'bytes': [11, 22],
      };
      journal.record(DiagnosticEvent.fromJson(json));
      const MediaDiagnostics(
        null,
        DiagnosticMediaComponent.taskTts,
      ).failure('arbitrary');
      MediaDiagnostics(
        journal.record,
        DiagnosticMediaComponent.taskAsr,
      ).failure('private-token');
      await journal.snapshot();
      final restored = DiagnosticJournal(store);
      addTearDown(restored.close);
      final zip = await ZipLogRepository(
        restored,
        uploadBundle: (_) async => fail('No upload'),
      ).prepare();
      final data = utf8.decode(
        ZipDecoder().decodeBytes(zip.bytes).files.single.content as List<int>,
      );
      expect(zip.count, 3);
      expect(data, contains('unknown'));
      for (final forbidden in ['private', 'secret', 'raw-exception', 'bytes']) {
        expect(data, isNot(contains(forbidden)));
      }
      expect(
        (await restored.snapshot()).events[1].media!.component,
        DiagnosticMediaComponent.unknown,
      );
    },
  );
}

class _Store implements DiagnosticStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String text) async {
    value = text;
  }
}
