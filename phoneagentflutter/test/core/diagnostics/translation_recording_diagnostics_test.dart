import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/core/diagnostics/translation_recording_diagnostics.dart';

void main() {
  test('fixed stages distinguish errors without exception text', () async {
    final events = <DiagnosticEvent>[];
    final diagnostics = TranslationRecordingDiagnostics(events.add);
    await expectLater(
      diagnostics.run('recordingLocal', () async {
        throw const FormatException('private-path and secret');
      }),
      throwsFormatException,
    );
    await expectLater(
      diagnostics.run('recordingPrepare', () async {
        throw PlatformException(
          code: 'private-native-error',
          message: 'secret',
        );
      }),
      throwsA(isA<PlatformException>()),
    );
    expect(events.map((e) => e.translation!.stage), [
      'recordingLocal',
      'recordingLocal',
      'recordingPrepare',
      'recordingPrepare',
    ]);
    expect(events[1].failureKind, DiagnosticFailureKind.format);
    expect(events[3].failureKind, DiagnosticFailureKind.platform);
    final text = events.map((e) => e.toJson()).join();
    expect(text, isNot(contains('secret')));
    expect(text, isNot(contains('private')));
  });
  test(
    'known native encoding code survives without raw error details',
    () async {
      final events = <DiagnosticEvent>[];
      final diagnostics = TranslationRecordingDiagnostics(events.add);
      await expectLater(
        diagnostics.run('recordingFinalize', () async {
          throw PlatformException(
            code: 'recording_encode_failed',
            message: 'private path',
            details: 'secret',
          );
        }),
        throwsA(isA<PlatformException>()),
      );
      expect(events.last.translation!.platformCode, 'recording_encode_failed');
      expect(events.last.toJson().toString(), isNot(contains('secret')));
    },
  );
  test(
    'void upload succeeds; absent finalization has a distinct result',
    () async {
      final events = <DiagnosticEvent>[];
      final diagnostics = TranslationRecordingDiagnostics(events.add);
      await diagnostics.run<void>('recordingUpload', () async {});
      await diagnostics.run<Object?>(
        'recordingFinalize',
        () async => null,
        missingIfNull: true,
      );
      expect(events[1].result, DiagnosticResult.succeeded);
      expect(events[3].result, DiagnosticResult.received);
      expect(
        DiagnosticEvent.fromJson(events[1].toJson()).translation!.stage,
        'recordingUpload',
      );
    },
  );
}
