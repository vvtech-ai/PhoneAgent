import 'dart:async';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/audio/audio_playback_focus.dart';
import 'package:phone_agent/core/audio/audio_resource_coordinator.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_audio_details.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_journal.dart';
import 'package:phone_agent/features/app_logs/data/zip_log_repository.dart';

Future<AudioLease> claim(
  AudioPlaybackFocus focus,
  String owner, {
  Future<void> Function(AudioLease)? stop,
  bool interruptible = true,
}) => focus.acquire(
  owner: owner,
  isCurrent: () => true,
  stop: stop ?? (_) async {},
  interruptible: interruptible,
);

void main() {
  test(
    'all formal owner labels round trip through persistent Journal and ZIP',
    () async {
      final store = _Store();
      final journal = DiagnosticJournal(store);
      addTearDown(journal.close);
      final focus = AudioPlaybackFocus(diagnostics: () => journal.record);
      const owners = [
        'conversation-capture',
        'conversation-tts',
        'call-monitor',
        'identity-capture',
        'clone-preview',
        'recording',
        'translation-app-audio',
        'translation-sip',
        'translation-livekit',
        'sensitive-raw-owner',
      ];
      for (final owner in owners) {
        final lease = await claim(focus, owner);
        expect(focus.release(lease), isTrue);
        expect(focus.release(lease), isFalse); // No duplicate release event.
      }
      await journal.snapshot();
      final restored = DiagnosticJournal(store);
      addTearDown(restored.close);
      final events = (await restored.snapshot()).events;
      expect(events.length, owners.length * 3);
      expect(
        events.map((e) => e.audio!.owner).toSet(),
        DiagnosticAudioOwner.values.toSet(),
      );
      expect(
        events
            .where((e) => e.result == DiagnosticResult.succeeded)
            .every((e) => e.audio!.lease > 0),
        isTrue,
      );
      final zip = await ZipLogRepository(
        restored,
        uploadBundle: (_) async {
          fail('Must not upload');
        },
      ).prepare();
      final file = ZipDecoder().decodeBytes(zip.bytes).files.single;
      final text = utf8.decode(file.content as List<int>);
      expect(text, isNot(contains('sensitive-raw-owner')));
      expect(text, contains('translationLivekit'));
      expect(text.split('\n').length, owners.length * 3);
    },
  );

  test('old format and hostile optional audio fields remain safe', () {
    final old = DiagnosticEvent(
      operation: DiagnosticOperation.accountRequest,
      result: DiagnosticResult.succeeded,
    ).toJson();
    expect(DiagnosticEvent.fromJson(old).audio, isNull);
    final event = DiagnosticEvent.fromJson({
      ...old,
      'audio': {
        'owner': 'private-owner',
        'stage': 'secret',
        'request': -1,
        'lease': 'credential',
        'blockedBy': 'private-owner',
        'extra': 'secret',
      },
    });
    expect(event.audio!.owner, DiagnosticAudioOwner.unknown);
    expect(event.audio!.stage, DiagnosticAudioStage.unknown);
    expect(event.audio!.request, 0);
    expect(event.audio!.lease, 0);
    expect(jsonEncode(event.toJson()), isNot(contains('secret')));
    expect(jsonEncode(event.toJson()), isNot(contains('private-owner')));
  });

  test('protected owner is identified without stopping it', () async {
    final events = <DiagnosticEvent>[];
    final focus = AudioPlaybackFocus(diagnostics: () => events.add);
    final old = await claim(focus, 'identity-capture', interruptible: false);
    await expectLater(claim(focus, 'recording'), throwsStateError);
    expect(events.last.audio!.blockedBy, DiagnosticAudioOwner.identityCapture);
    expect(events.last.result, DiagnosticResult.failed);
    expect(
      events.any((e) => e.audio!.stage == DiagnosticAudioStage.stop),
      isFalse,
    );
    expect(focus.owns(old), isTrue);
    focus.release(old);
  });

  test('superseded requests are cancelled not reported as acquired', () async {
    final events = <DiagnosticEvent>[];
    final focus = AudioPlaybackFocus(diagnostics: () => events.add);
    final old = claim(focus, 'recording');
    final failed = expectLater(old, throwsStateError);
    final next = claim(focus, 'clone-preview');
    await failed;
    focus.release(await next);
    final cancelled = events
        .where((e) => e.result == DiagnosticResult.cancelled)
        .single;
    expect(cancelled.audio!.owner, DiagnosticAudioOwner.recording);
    expect(cancelled.audio!.lease, 0);
  });

  test(
    'wait timeout retains ownership and late stop keeps its original sink',
    () async {
      final a = <DiagnosticEvent>[], b = <DiagnosticEvent>[];
      var current = a;
      final focus = AudioPlaybackFocus(
        diagnostics: () => current.add,
        stopTimeout: const Duration(milliseconds: 5),
      );
      final gate = Completer<void>();
      var stops = 0;
      final old = await claim(
        focus,
        'recording',
        stop: (_) {
          stops++;
          return gate.future;
        },
      );
      current = b;
      await expectLater(
        claim(focus, 'clone-preview'),
        throwsA(isA<TimeoutException>()),
      );
      expect(focus.owns(old), isTrue);
      expect(a.last.audio!.stage, DiagnosticAudioStage.stopWait);
      expect(a.last.failureKind, DiagnosticFailureKind.timeout);
      expect(
        a.any((e) => e.audio!.stage == DiagnosticAudioStage.release),
        isFalse,
      );
      final next = claim(focus, 'clone-preview');
      gate.complete();
      focus.release(await next);
      expect(stops, 1);
      expect(a.last.audio!.stage, DiagnosticAudioStage.release);
      expect(
        a.every((e) => e.audio!.owner == DiagnosticAudioOwner.recording),
        isTrue,
      );
      expect(
        b.every((e) => e.audio!.owner == DiagnosticAudioOwner.clonePreview),
        isTrue,
      );
      expect(
        a
            .where(
              (e) =>
                  e.audio!.stage == DiagnosticAudioStage.stop &&
                  e.result == DiagnosticResult.succeeded,
            )
            .length,
        1,
      );
    },
  );

  test(
    'native stop TimeoutException is failure, not coordinator wait timeout',
    () async {
      final events = <DiagnosticEvent>[];
      final error = TimeoutException('secret-native-error');
      final focus = AudioPlaybackFocus(diagnostics: () => events.add);
      final lease = await claim(
        focus,
        'recording',
        stop: (_) async => throw error,
      );
      await expectLater(focus.stopAll(), throwsA(same(error)));
      expect(focus.owns(lease), isTrue);
      expect(events.last.audio!.stage, DiagnosticAudioStage.stop);
      expect(events.last.result, DiagnosticResult.failed);
      expect(
        events.any((e) => e.audio!.stage == DiagnosticAudioStage.stopWait),
        isFalse,
      );
      expect(
        jsonEncode(events.map((e) => e.toJson()).toList()),
        isNot(contains('secret-native-error')),
      );
      focus.release(lease);
    },
  );

  test(
    'sink selection and emission failures cannot change audio outcomes',
    () async {
      for (final failFactory in [true, false]) {
        final focus = AudioPlaybackFocus(
          diagnostics: () {
            if (failFactory) throw StateError('factory');
            return (_) => throw StateError('sink');
          },
        );
        final error = StateError('original');
        final old = await claim(
          focus,
          'recording',
          stop: (_) async => throw error,
        );
        await expectLater(focus.stopAll(), throwsA(same(error)));
        expect(focus.owns(old), isTrue);
        focus.release(old);
        await claim(focus, 'clone-preview');
        await focus.stopAll();
        expect(focus.active, isNull);
      }
    },
  );
}

class _Store implements DiagnosticStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String text) async => value = text;
}
