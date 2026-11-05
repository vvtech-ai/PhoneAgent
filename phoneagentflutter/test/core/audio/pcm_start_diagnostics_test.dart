import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/audio/diagnosed_pcm_output.dart';
import 'package:phone_agent/core/audio/pcm_output.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/core/diagnostics/media_diagnostics.dart';
import 'package:phone_agent/features/conversation/data/voice/device_pcm_output.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('phone_agent/pcm_output');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'native start context survives journal round trip without private fields',
    () async {
      final events = <DiagnosticEvent>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'start') {
          throw PlatformException(
            code: 'output_start_failed',
            message: 'PRIVATE',
            details: {
              'phase': 'engineStart',
              'domain': 'osStatus',
              'code': -10868,
              'appState': 0,
              'route': 'bluetooth',
              'engineRunning': false,
              'outputPresent': true,
              'outputId': call.arguments['outputId'],
              'message': 'PRIVATE TEXT',
              'deviceName': 'PRIVATE PHONE',
              'token': 'SECRET',
            },
          );
        }
        return true;
      });
      final output = DiagnosedPcmOutput(
        DevicePcmOutput(platform: TargetPlatform.iOS, web: false),
        MediaDiagnostics(events.add, DiagnosticMediaComponent.pcmOutput),
      );
      await expectLater(output.start(24000), throwsA(isA<PcmOutputFailure>()));
      final failed = events.last;
      expect(failed.result, DiagnosticResult.failed);
      expect(failed.media!.reason, DiagnosticMediaReason.deviceStartFailed);
      final copy = DiagnosticEvent.fromJson(
        jsonDecode(jsonEncode(failed.toJson())),
      );
      expect(copy.media!.native!.phase, DiagnosticPcmPhase.engineStart);
      expect(copy.media!.native!.domain, DiagnosticPcmDomain.osStatus);
      expect(copy.media!.native!.code, -10868);
      expect(copy.media!.native!.route, DiagnosticPcmRoute.bluetooth);
      expect(copy.media!.native!.outputPresent, isTrue);
      expect(copy.media!.native!.outputId, isNotEmpty);
      expect(copy.elapsedMs, greaterThanOrEqualTo(0));
      expect(jsonEncode(copy.toJson()), isNot(matches('PRIVATE|SECRET')));
      await output.stop();
      expect(
        events
            .where((e) => e.media!.stage == DiagnosticMediaStage.stop)
            .map((e) => e.result),
        [DiagnosticResult.started, DiagnosticResult.succeeded],
      );
    },
  );

  test('unknown native fields and unsafe identifiers cannot enter export', () {
    final native = DiagnosticPcmDetails.parse({
      'phase': 'PRIVATE',
      'domain': 'SECRET',
      'code': 'PRIVATE',
      'route': 'PRIVATE',
      'outputId': '13900000000',
      'appState': -9,
    })!;
    expect(native.phase, DiagnosticPcmPhase.unknown);
    expect(native.domain, DiagnosticPcmDomain.other);
    expect(native.outputId, isEmpty);
    expect(
      jsonEncode(native.toJson()),
      isNot(matches('PRIVATE|SECRET|13900000000')),
    );
    final media = DiagnosticMediaDetails.fromJson({
      'requestId': 'SECRET',
      'attempt': 1000,
      'audioBytes': -1,
      'component': 'taskTts',
      'stage': 'receive',
      'native': 'PRIVATE',
    });
    expect(media.toJson()['attempt'], 100);
    expect(media.toJson()['audioBytes'], 0);
    expect(media.toJson().containsKey('requestId'), isFalse);
    expect(media.native, isNull);
  });
}
