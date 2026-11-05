import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/diagnostics/clone_diagnostics.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/features/voice_clone/data/clone_preview_diagnostics.dart';
import 'package:phone_agent/features/voice_clone/data/plugin_clone_preview_player.dart';

void main() {
  test(
    'native session failure identifies the call and survives log export',
    () {
      for (final step in ['deactivate', 'setCategory', 'setActive']) {
        final events = <DiagnosticEvent>[];
        ClonePreviewDiagnostics(CloneDiagnostics(events.add)).failed(
          ClonePreviewStage.prepare,
          PlatformException(
            code: 'DarwinAudioError',
            details: {
              'nativeStep': step,
              'errorDomain': 'NSOSStatusErrorDomain',
              'nativeCode': 561017449,
              'sessionCategory': 'playAndRecord',
              'sessionMode': 'default',
              'sessionOptions': 8,
              'nativeAttempt': 3,
              'untrusted': 'secret-audio-path',
            },
          ),
        );
        final encoded = jsonEncode(events.single.toJson());
        final decoded = DiagnosticEvent.fromJson(
          jsonDecode(encoded) as Map<String, dynamic>,
        ).clonePreview!;
        expect(decoded.nativeStep, step);
        expect(decoded.nativeCode, 561017449);
        expect(decoded.errorDomain, 'NSOSStatusErrorDomain');
        expect(decoded.sessionCategory, 'playAndRecord');
        expect(decoded.sessionMode, 'default');
        expect(decoded.sessionOptions, 8);
        expect(decoded.nativeAttempt, 3);
        expect(encoded, isNot(contains('secret')));
      }
    },
  );

  test('native session metadata rejects arbitrary strings and wrong types', () {
    final events = <DiagnosticEvent>[];
    ClonePreviewDiagnostics(CloneDiagnostics(events.add)).failed(
      ClonePreviewStage.prepare,
      PlatformException(
        code: 'DarwinAudioError',
        details: {
          'nativeStep': 'secret-step',
          'sessionCategory': 'secret-category',
          'sessionMode': 'secret-mode',
          'errorDomain': 'secret-domain',
          'nativeCode': 'secret-code',
          'sessionOptions': 'secret-options',
          'nativeAttempt': 'secret-attempt',
        },
      ),
    );
    expect(jsonEncode(events.single.toJson()), isNot(contains('secret')));
    expect(events.single.clonePreview!.nativeCode, isNull);
    expect(events.single.clonePreview!.sessionOptions, isNull);
  });

  test('bounded WAV metadata survives export without audio bytes', () {
    final events = <DiagnosticEvent>[];
    final d = ClonePreviewDiagnostics(CloneDiagnostics(events.add));
    d.input(_wav());
    final decoded = DiagnosticEvent.fromJson(
      jsonDecode(jsonEncode(events.single.toJson())) as Map<String, dynamic>,
    );
    expect(decoded.clonePreview!.toJson(), {
      'stage': 'input',
      'container': 'wav',
      'byteCount': 46,
      'wavFormat': 1,
      'channels': 1,
      'sampleRate': 24000,
      'bitsPerSample': 16,
      'dataBytes': 2,
    });
    expect(decoded.sessionId, isNotEmpty);
  });

  test('truncated/other containers are observed without rejecting input', () {
    final events = <DiagnosticEvent>[];
    final d = ClonePreviewDiagnostics(CloneDiagnostics(events.add));
    for (final bytes in [
      Uint8List(0),
      Uint8List.fromList('RIFF'.codeUnits),
      Uint8List.fromList([255, 241]),
      Uint8List.fromList('ID3'.codeUnits),
    ]) {
      d.input(bytes);
    }
    expect(events.map((e) => e.clonePreview!.container), [
      'unknown',
      'unknown',
      'aac',
      'mp3',
    ]);
    final broken = _wav();
    ByteData.sublistView(broken).setUint32(16, 0xffffffff, Endian.little);
    d.input(broken);
    expect(events.last.clonePreview!.wavFormat, isNull);
  });

  test(
    'platform failure records only allowlisted code/domain and native number',
    () {
      final events = <DiagnosticEvent>[];
      final d = ClonePreviewDiagnostics(CloneDiagnostics(events.add));
      d.failed(
        ClonePreviewStage.prepare,
        PlatformException(
          code: 'DarwinAudioError',
          message: 'secret-token /private/user.wav',
          details:
              'Error Domain=AVFoundationErrorDomain Code=-11828 secret-body',
        ),
      );
      final details = events.single.clonePreview!;
      expect(details.errorCode, 'DarwinAudioError');
      expect(details.errorDomain, 'AVFoundationErrorDomain');
      expect(details.nativeCode, -11828);
      expect(jsonEncode(events.single.toJson()), isNot(contains('secret')));
      expect(jsonEncode(events.single.toJson()), isNot(contains('/private')));
      d.failed(
        ClonePreviewStage.event,
        PlatformException(
          code: 'secret-token',
          message: 'secret-body',
          details: {'url': 'secret-url'},
        ),
      );
      expect(events.last.clonePreview!.errorCode, 'other');
      expect(jsonEncode(events.last.toJson()), isNot(contains('secret')));
    },
  );

  test(
    'prepare exception is preserved, logged and cleaned exactly once',
    () async {
      final events = <DiagnosticEvent>[];
      final error = PlatformException(code: 'DarwinAudioError');
      final native = _Native(prepareError: error);
      final player = PluginClonePreviewPlayer(
        create: () => native,
        diagnostics: CloneDiagnostics(events.add, platform: 'iOS'),
      );
      await expectLater(player.play(_wav()), throwsA(same(error)));
      expect(_failed(events), [ClonePreviewStage.prepare]);
      expect(native.disposals, 1);
      expect(
        events
            .where(
              (e) => e.clonePreview?.stage == ClonePreviewStage.sourceCleanup,
            )
            .last
            .result,
        DiagnosticResult.succeeded,
      );
      expect(events.map((e) => e.sessionId).toSet().length, 1);
      await player.close();
      await native.controller.close();
    },
  );

  test(
    'async player event failure and playback failure remain distinguishable',
    () async {
      final events = <DiagnosticEvent>[];
      final native = _Native(
        eventError: PlatformException(code: 'AudioPlayerError'),
      );
      final player = PluginClonePreviewPlayer(
        create: () => native,
        diagnostics: CloneDiagnostics(events.add),
      );
      await expectLater(player.play(_wav()), throwsStateError);
      expect(_failed(events), contains(ClonePreviewStage.event));
      expect(native.disposals, 1);
      await player.close();
      await native.controller.close();
    },
  );

  test('sink errors cannot break playback or cleanup', () async {
    final native = _Native();
    final player = PluginClonePreviewPlayer(
      create: () => native,
      diagnostics: CloneDiagnostics((_) => throw StateError('sink')),
    );
    await player.play(_wav());
    expect(native.disposals, 1);
    await player.close();
    await native.controller.close();
  });
}

List<ClonePreviewStage> _failed(List<DiagnosticEvent> events) => events
    .where((e) => e.result == DiagnosticResult.failed)
    .map((e) => e.clonePreview!.stage)
    .toList();

Uint8List _wav() {
  final bytes = Uint8List(46), view = ByteData(46);
  bytes.setRange(0, 4, 'RIFF'.codeUnits);
  bytes.setRange(8, 12, 'WAVE'.codeUnits);
  bytes.setRange(12, 16, 'fmt '.codeUnits);
  bytes.setRange(36, 40, 'data'.codeUnits);
  view.setUint32(16, 16, Endian.little);
  view.setUint16(20, 1, Endian.little);
  view.setUint16(22, 1, Endian.little);
  view.setUint32(24, 24000, Endian.little);
  view.setUint16(34, 16, Endian.little);
  view.setUint32(40, 2, Endian.little);
  for (final i in [
    16,
    17,
    18,
    19,
    20,
    21,
    22,
    23,
    24,
    25,
    26,
    27,
    34,
    35,
    40,
    41,
    42,
    43,
  ]) {
    bytes[i] = view.getUint8(i);
  }
  return bytes;
}

class _Native extends Fake implements AudioPlayer {
  _Native({this.prepareError, this.eventError});
  final Object? prepareError, eventError;
  final controller = StreamController<AudioEvent>.broadcast();
  int disposals = 0;
  @override
  Stream<AudioEvent> get eventStream => controller.stream;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #play) {
      if (prepareError != null) return Future<void>.error(prepareError!);
      if (eventError != null) {
        controller.addError(eventError!);
      } else {
        controller.add(const AudioEvent(eventType: AudioEventType.complete));
      }
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }

  @override
  Future<void> dispose() async {
    disposals++;
  }
}
