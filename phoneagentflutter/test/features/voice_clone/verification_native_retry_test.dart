import 'dart:async';
import 'package:phone_agent/features/voice_clone/domain/clone_verification_admission.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/audio/audio_playback_focus.dart';
import 'package:phone_agent/features/voice_clone/data/device_identity_capture_port.dart';
import 'package:phone_agent/features/voice_clone/data/focused_identity_capture_port.dart';
import 'package:phone_agent/features/voice_clone/data/preview_clone_flow.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_verification.dart';
import 'package:phone_agent/features/voice_clone/presentation/controller/clone_verification_controller.dart';

class _Admission extends PreviewFlowVerification {
  _Admission() : super(PreviewCloneFlow());
  bool reject = true;
  @override
  Future<VerificationAttempt> initialize(
    VerificationIdentity identity,
    String meta,
  ) {
    if (reject) {
      throw CloneVerificationAdmissionFailure.parse(
        '本次声音克隆仍在处理中，请稍后同步结果，勿重复认证。',
      )!;
    }
    return super.initialize(identity, meta);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('phone_agent/identity_capture');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test(
      '$platform rejected init waits for original native owner before a fresh retry',
      () async {
        String? owner;
        final releasing = Completer<void>();
        final releaseEntered = Completer<void>();
        final prepared = <String>[];
        messenger.setMockMethodCallHandler(channel, (call) async {
          final lease = (call.arguments as Map)['session'] as String;
          if (call.method == 'prepare') {
            if (owner != null) throw PlatformException(code: 'capture_busy');
            owner = lease;
            prepared.add(lease);
            return 'synthetic';
          }
          if (call.method == 'waitForRelease' && prepared.length == 1) {
            if (!releaseEntered.isCompleted) releaseEntered.complete();
            await releasing.future;
          }
          if (call.method == 'abort' || call.method == 'waitForRelease') {
            if (call.method == 'waitForRelease' && owner == lease) owner = null;
            return null;
          }
          return {
            'code': 1000,
            'reason': '',
            'deviceModel': 'synthetic',
            'networkType': 'WIFI',
            'networkValidated': true,
          };
        });
        final repository = _Admission();
        final focus = AudioPlaybackFocus();
        CloneVerificationController create() {
          final device = DeviceIdentityCapturePort(
            web: false,
            platform: platform,
          );
          return CloneVerificationController(
            repository: repository,
            capture: FocusedIdentityCapturePort(
              device,
              focus,
              waitForRelease: device.waitForRelease,
              isCurrent: () => true,
            ),
            isCurrent: () => true,
          );
        }

        const identity = VerificationIdentity(
          name: '演练用户',
          number: '000000200001010005',
        );
        final first = create();
        final operation = first.start(identity);
        await releaseEntered.future;
        expect(first.state.busy, isTrue);
        releasing.complete();
        await operation;
        expect(owner, isNull);
        expect(first.state.phase, VerificationPhase.failed);
        expect(first.state.admissionFailure?.message, contains('仍在处理中'));
        repository.reject = false;
        final second = create();
        await second.start(identity);
        expect(second.state.phase, VerificationPhase.passed);
        expect(prepared.toSet(), hasLength(2));
        expect(owner, isNull);
        first.dispose();
        second.dispose();
      },
    );
  }
}
