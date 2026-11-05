import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/data/voice/fallback_voice_input_session.dart';
import 'package:phone_agent/features/conversation/domain/voice/voice_gateway_event.dart';
import 'package:phone_agent/features/conversation/presentation/controller/voice_input_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/voice_input_state.dart';
import 'fallback_voice_input_session_test.dart' show InputFake;
import 'voice_input_fake.dart' show InputPermissionFake;

void main() {
  final uri = Uri.parse('ws://synthetic.invalid/asr?languageCode=zh-CN&keep=1');
  late InputFake primary, fallback;
  late FallbackVoiceInputSession session;
  late Future<String> Function() read;
  var current = true, reads = 0;
  setUp(() {
    primary = InputFake();
    fallback = InputFake();
    current = true;
    reads = 0;
    read = () async => 'en-US';
    session = FallbackVoiceInputSession(
      primary: primary,
      createFallback: () => fallback,
      fallbackEndpoint: Uri.parse(
        'ws://synthetic.invalid/fallback?userId=a&languageCode=zh-CN',
      ),
      isCurrent: () => current,
      readLanguage: () {
        reads++;
        return read();
      },
    );
  });
  tearDown(() async {
    await session.cancel();
    await primary.stream.close();
    await fallback.stream.close();
  });
  test(
    'both transports use one language snapshot and retain other parameters',
    () async {
      await session.start(uri);
      expect(primary.endpoint!.queryParameters, {
        'languageCode': 'en-US',
        'keep': '1',
      });
      read = () async => 'ja-JP';
      primary.emit(const VoiceGatewayFailure('provider_error'));
      await Future<void>.delayed(Duration.zero);
      expect(fallback.endpoint!.queryParameters, {
        'userId': 'a',
        'languageCode': 'en-US',
      });
      expect(reads, 1);
    },
  );
  for (final reason in ['cancel', 'release', 'owner']) {
    test(
      'language resolving then $reason never starts late transport',
      () async {
        final gate = Completer<String>();
        read = () => gate.future;
        final started = session.start(uri);
        if (reason == 'cancel') await session.cancel();
        if (reason == 'release') await session.release();
        if (reason == 'owner') current = false;
        gate.complete('ja-JP');
        await started;
        expect(primary.starts + fallback.starts, 0);
      },
    );
  }
  test('source failure never silently starts Chinese', () async {
    read = () async => throw StateError('source');
    await expectLater(session.start(uri), throwsStateError);
    expect(primary.starts + fallback.starts, 0);
  });
  test('invalid language never starts transport', () async {
    read = () async => 'invalid';
    await expectLater(session.start(uri), throwsFormatException);
    expect(primary.starts + fallback.starts, 0);
  });
  test('three second bound reaches existing controller retry state', () async {
    final gate = Completer<String>();
    read = () => gate.future;
    final controller = VoiceInputController(
      createSession: () => session,
      permissions: InputPermissionFake(),
      endpoint: uri,
      isCurrent: () => true,
      canSubmit: () => true,
      submit: (_) => throw StateError('no submit'),
    );
    await controller.press();
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.canPress, true);
    expect(controller.state.notice, contains('语音识别中断'));
    gate.complete('en-US');
    await Future<void>.delayed(Duration.zero);
    expect(primary.starts + fallback.starts, 0);
    expect(controller.state.phase, VoiceInputPhase.idle);
    controller.dispose();
  });
}
