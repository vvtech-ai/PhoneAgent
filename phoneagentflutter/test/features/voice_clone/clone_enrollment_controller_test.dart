import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_enrollment.dart';
import 'package:phone_agent/features/voice_clone/data/preview_clone_enrollment_port.dart';
import 'package:phone_agent/features/voice_clone/presentation/controller/clone_enrollment_controller.dart';

const syntheticIdentity = '000000200001010005';
void main() {
  test('v65 identity date and checksum rule, no area-code invention', () {
    expect(validCloneIdentityNumber(syntheticIdentity), true);
    expect(validCloneIdentityNumber('000000200001010009'), false);
    expect(validCloneIdentityNumber('000000200013010008'), false);
    expect(validCloneIdentityNumber('short'), false);
  });
  test('consent and identity validation gate all external work', () async {
    final port = _Port();
    final c = CloneEnrollmentController(port);
    c.next();
    expect(c.state.step, CloneStep.consent);
    await c.submitIdentity('Sample', syntheticIdentity);
    expect(port.events, isEmpty);
    c.agree(true);
    c.next();
    await c.submitIdentity('Sample', 'bad');
    expect(c.state.error, isNotEmpty);
    expect(port.events, isEmpty);
    c.dispose();
  });
  test(
    'SDK completion is not verification; ordered stages and single flight',
    () async {
      final port = _Port()..collection = Completer<void>();
      final c = _ready(port);
      final phases = <CloneStep>[];
      c.addListener((state) => phases.add(state.step));
      final operation = c.submitIdentity('Sample', syntheticIdentity);
      await Future<void>.delayed(Duration.zero);
      await c.submitIdentity('Sample', syntheticIdentity);
      expect(c.state.step, CloneStep.collecting);
      expect(c.exitBlocked, true);
      expect(port.events, ['replacement', 'initialize:false', 'collect']);
      port.collection!.complete();
      await operation;
      expect(port.events, [
        'replacement',
        'initialize:false',
        'collect',
        'verify',
        'generate',
      ]);
      expect(
        phases,
        containsAllInOrder([
          CloneStep.collecting,
          CloneStep.checking,
          CloneStep.generating,
          CloneStep.candidate,
        ]),
      );
      expect(c.needsExitConfirmation, true);
      c.dispose();
    },
  );
  test(
    'replacement cancel never initializes; confirmation is explicit',
    () async {
      final port = _Port()..replacement = true;
      final c = _ready(port);
      await c.submitIdentity('Sample', syntheticIdentity);
      expect(c.state.replacement, true);
      c.cancelReplacement();
      expect(port.events, ['replacement']);
      await c.submitIdentity('Sample', syntheticIdentity);
      await c.confirmReplacement();
      expect(port.events, contains('initialize:true'));
      c.dispose();
    },
  );
  test('dispose during SDK work stops all downstream operations', () async {
    final port = _Port()..collection = Completer<void>();
    final c = _ready(port);
    final operation = c.submitIdentity('Sample', syntheticIdentity);
    await Future<void>.delayed(Duration.zero);
    c.dispose();
    port.collection!.complete();
    await operation;
    expect(port.events, isNot(contains('verify')));
    expect(port.closed, true);
  });
  test(
    'confirm respects save flag and stops preview; rerecord resets consent',
    () async {
      final port = _Port();
      final c = _ready(port);
      await c.submitIdentity('Sample', syntheticIdentity);
      c.rerecord();
      expect(c.state.step, CloneStep.consent);
      expect(c.state.agreed, false);
      c.agree(true);
      c.next();
      await c.submitIdentity('Sample', syntheticIdentity);
      c.saveRecording(false);
      await c.confirm();
      expect(port.events, contains('confirm:false'));
      expect(c.state.step, CloneStep.confirmed);
      expect(c.needsExitConfirmation, false);
      c.dispose();
    },
  );
  for (final scenario in [
    ClonePreviewScenario.denied,
    ClonePreviewScenario.verificationFailure,
    ClonePreviewScenario.generationFailure,
  ]) {
    test('$scenario gives actionable error and explicit retry only', () async {
      final c = _ready(
        PreviewCloneEnrollmentPort(scenario, delay: Duration.zero),
      );
      await c.submitIdentity('Sample', syntheticIdentity);
      expect(c.state.step, CloneStep.identity);
      expect(c.state.error, isNotEmpty);
      expect(c.state.busy, false);
      await c.submitIdentity('Sample', syntheticIdentity);
      expect(c.state.step, CloneStep.candidate);
      c.dispose();
    });
  }
  test('preview and confirmation failure do not report success', () async {
    final c = _ready(
      PreviewCloneEnrollmentPort(
        ClonePreviewScenario.previewFailure,
        delay: Duration.zero,
      ),
    );
    await c.submitIdentity('Sample', syntheticIdentity);
    await c.togglePreview();
    expect(c.state.error, contains('试听失败'));
    expect(c.state.playing, false);
    await c.togglePreview();
    expect(c.state.error, isEmpty);
    c.dispose();
    final other = _ready(
      PreviewCloneEnrollmentPort(
        ClonePreviewScenario.confirmationFailure,
        delay: Duration.zero,
      ),
    );
    await other.submitIdentity('Sample', syntheticIdentity);
    await other.confirm();
    expect(other.state.step, CloneStep.candidate);
    expect(other.state.error, isNotEmpty);
    await other.confirm();
    expect(other.state.step, CloneStep.confirmed);
    other.dispose();
  });
}

CloneEnrollmentController _ready(CloneEnrollmentPort port) =>
    CloneEnrollmentController(port)
      ..agree(true)
      ..next();

class _Port implements CloneEnrollmentPort {
  final events = <String>[];
  bool replacement = false, closed = false;
  Completer<void>? collection;
  @override
  Future<bool> replacementRequired(String number) async {
    events.add('replacement');
    return replacement;
  }

  @override
  Future<CloneVerification> initialize(
    String name,
    String number,
    bool confirmed,
  ) async {
    events.add('initialize:$confirmed');
    return const CloneVerification('sample', 'Synthetic script');
  }

  @override
  Future<void> collect(CloneVerification verification) async {
    events.add('collect');
    await collection?.future;
  }

  @override
  Future<void> verify(CloneVerification verification) async {
    events.add('verify');
  }

  @override
  Future<void> generate(CloneVerification verification) async {
    events.add('generate');
  }

  @override
  Future<void> preview() async {}
  @override
  void stopPreview() {}
  @override
  Future<void> confirm({required bool saveRecording}) async {
    events.add('confirm:$saveRecording');
  }

  @override
  void close() {
    closed = true;
  }
}
