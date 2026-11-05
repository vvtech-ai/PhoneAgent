import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_verification.dart';
import 'package:phone_agent/features/voice_clone/presentation/controller/clone_verification_controller.dart';

const identity = VerificationIdentity(
  name: 'Synthetic',
  number: '000000200001010005',
);
const attempt = VerificationAttempt(
  id: 'attempt',
  certifyId: 'private-certify',
  script: '合成文本',
  expiresAt: '2026-09-18T12:00:00',
);
VerificationSnapshot snapshot(
  VerificationStatus status, {
  String id = 'attempt',
  String? code,
}) =>
    VerificationSnapshot(id, status, attempt.expiresAt, providerSubCode: code);
Future<void> tick() => Future<void>.delayed(Duration.zero);

class _Repo implements CloneVerificationRepository {
  int initializations = 0, reads = 0;
  final observed = <VerificationObservation>[];
  final responses = <VerificationSnapshot>[];
  bool initFail = false, readFail = false, observationFail = false;
  Completer<VerificationAttempt>? initGate;
  Completer<VerificationSnapshot>? readGate;
  Completer<void>? observationGate;
  @override
  Future<bool> replacementRequired(String identityNumber) async => false;
  @override
  Future<VerificationAttempt> initialize(
    VerificationIdentity identity,
    String metaInfo,
  ) async {
    initializations++;
    expect(metaInfo, 'private-meta');
    if (initFail) throw StateError('not exposed');
    return initGate?.future ?? Future.value(attempt);
  }

  @override
  Future<VerificationSnapshot> read(String attemptId) async {
    expect(attemptId, 'attempt');
    reads++;
    if (readFail) throw StateError('not exposed');
    if (readGate != null) return readGate!.future;
    return responses.isEmpty
        ? snapshot(VerificationStatus.pass)
        : responses.removeAt(0);
  }

  @override
  Future<void> observe(
    String attemptId,
    VerificationObservation observation,
  ) async {
    expect(attemptId, 'attempt');
    observed.add(observation);
    if (observationFail) throw StateError('not exposed');
    await observationGate?.future;
  }
}

class _Capture implements IdentityCapturePort {
  int prepared = 0, captured = 0, aborted = 0, code = 1000;
  bool prepareFail = false, captureFail = false;
  Completer<String>? prepareGate;
  Completer<IdentityCaptureResult>? captureGate;
  @override
  Future<String> prepare() async {
    prepared++;
    if (prepareFail) throw StateError('native detail');
    return prepareGate?.future ?? Future.value('private-meta');
  }

  @override
  Future<IdentityCaptureResult> capture(String certifyId) async {
    expect(certifyId, 'private-certify');
    captured++;
    if (captureFail) throw StateError('native detail');
    return captureGate?.future ?? Future.value(IdentityCaptureResult(code));
  }

  @override
  Future<void> abort() async {
    aborted++;
  }
}

void main() {
  test(
    'initialization rejection releases prepared owner before retry',
    () async {
      final repo = _Repo()..initFail = true;
      final sdk = _Capture();
      final first = CloneVerificationController(
        repository: repo,
        capture: sdk,
        isCurrent: () => true,
      );
      await first.start(identity);
      expect(sdk.aborted, 1);
      expect(sdk.captured, 0);
      repo.initFail = false;
      final retry = CloneVerificationController(
        repository: repo,
        capture: _Capture(),
        isCurrent: () => true,
      );
      await retry.start(identity);
      expect(retry.state.phase, VerificationPhase.passed);
      first.dispose();
      retry.dispose();
    },
  );
  late _Repo repo;
  late _Capture sdk;
  late CloneVerificationController controller;
  late bool current;
  setUp(() {
    repo = _Repo();
    sdk = _Capture();
    current = true;
    controller = CloneVerificationController(
      repository: repo,
      capture: sdk,
      isCurrent: () => current,
      maxPolls: 3,
      delay: (_) => tick(),
    );
  });
  tearDown(() {
    if (controller.mounted) controller.dispose();
  });
  for (final code in [1000, 2006]) {
    test(
      'SDK $code awaits matching server PASS and single initialization',
      () async {
        sdk.code = code;
        repo.readGate = Completer<VerificationSnapshot>();
        final operation = controller.start(identity);
        await tick();
        await controller.start(identity);
        await controller.synchronize();
        expect(controller.state.phase, VerificationPhase.checking);
        expect(controller.verifiedAttemptId, null);
        expect(repo.initializations, 1);
        expect(sdk.captured, 1);
        expect(repo.reads, 1);
        repo.readGate!.complete(snapshot(VerificationStatus.pass));
        await operation;
        expect(controller.verifiedAttemptId, 'attempt');
        expect(repo.observed.single.sdkCode, code);
        await controller.start(identity);
        await controller.synchronize();
        expect(repo.initializations, 1);
        expect(repo.reads, 1);
      },
    );
  }
  test('server PROCESSING/INITIATED poll in order, not fake ready', () async {
    repo.responses.addAll([
      snapshot(VerificationStatus.initiated),
      snapshot(VerificationStatus.processing),
      snapshot(VerificationStatus.pass),
    ]);
    await controller.start(identity);
    expect(repo.reads, 3);
    expect(controller.state.phase, VerificationPhase.passed);
    expect(repo.observed.length, 1);
  });
  for (final code in [1003, 1001, 2002, -1]) {
    test(
      'SDK $code never queries server or exposes verified attempt',
      () async {
        sdk.code = code;
        await controller.start(identity);
        await controller.synchronize();
        expect(
          controller.state.phase,
          code == 1003
              ? VerificationPhase.cancelled
              : VerificationPhase.rejected,
        );
        expect(controller.verifiedAttemptId, null);
        expect(repo.reads, 0);
        expect(repo.observed.single.sdkCode, code);
      },
    );
  }
  for (final status in [
    VerificationStatus.fail,
    VerificationStatus.cancelled,
    VerificationStatus.expired,
    VerificationStatus.needRetry,
  ]) {
    test(
      'server $status stops immediately and never authorizes generation',
      () async {
        repo.responses.add(snapshot(status));
        await controller.start(identity);
        await controller.synchronize();
        expect(repo.reads, 1);
        expect(controller.verifiedAttemptId, null);
        expect(
          controller.state.phase,
          status == VerificationStatus.cancelled
              ? VerificationPhase.cancelled
              : VerificationPhase.rejected,
        );
      },
    );
  }
  test(
    'known risk/read-aloud failures remain distinct safe UI issues',
    () async {
      repo.responses.add(snapshot(VerificationStatus.fail, code: '220'));
      await controller.start(identity);
      expect(controller.state.issue, VerificationIssue.readAloud);
    },
  );
  test('poll limit supports only same-attempt GET recovery', () async {
    repo.responses.addAll(
      List.generate(3, (_) => snapshot(VerificationStatus.processing)),
    );
    await controller.start(identity);
    expect(repo.reads, 3);
    expect(controller.state.issue, VerificationIssue.pollLimit);
    await controller.synchronize();
    expect(repo.reads, 4);
    expect(repo.initializations, 1);
    expect(sdk.captured, 1);
    expect(controller.verifiedAttemptId, 'attempt');
    expect(repo.observed.length, 1);
  });
  test(
    'query failure resynchronizes without another SDK or observation',
    () async {
      repo.readFail = true;
      await controller.start(identity);
      expect(controller.state.issue, VerificationIssue.request);
      repo.readFail = false;
      await controller.synchronize();
      expect(repo.initializations, 1);
      expect(sdk.captured, 1);
      expect(repo.observed.length, 1);
      expect(controller.verifiedAttemptId, 'attempt');
    },
  );
  test('cross-attempt response is terminal conflict even for PASS', () async {
    repo.responses.add(snapshot(VerificationStatus.pass, id: 'other'));
    await controller.start(identity);
    await controller.synchronize();
    expect(controller.state.issue, VerificationIssue.conflict);
    expect(controller.verifiedAttemptId, null);
    expect(repo.reads, 1);
  });
  test('failed observation never downgrades server PASS or retries', () async {
    repo.observationFail = true;
    await controller.start(identity);
    await tick();
    expect(controller.verifiedAttemptId, 'attempt');
    expect(controller.state.observationFailed, true);
    await controller.synchronize();
    expect(repo.observed.length, 1);
  });
  test('slow observation does not hold up successful verification', () async {
    repo.observationGate = Completer<void>();
    await controller.start(identity);
    expect(controller.verifiedAttemptId, 'attempt');
    repo.observationGate!.complete();
  });
  for (final failure in ['prepare', 'init', 'capture']) {
    test(
      '$failure failure never automatically repeats the operation',
      () async {
        sdk.prepareFail = failure == 'prepare';
        repo.initFail = failure == 'init';
        sdk.captureFail = failure == 'capture';
        await controller.start(identity);
        await controller.start(identity);
        await controller.synchronize();
        expect(controller.state.phase, VerificationPhase.failed);
        expect(sdk.prepared, 1);
        expect(repo.initializations, failure == 'prepare' ? 0 : 1);
        expect(repo.reads, 0);
        expect(repo.observed, isEmpty);
      },
    );
  }
  test(
    'dispose during prepare cannot send identity or initialize SDK flow',
    () async {
      sdk.prepareGate = Completer<String>();
      final operation = controller.start(identity);
      controller.dispose();
      sdk.prepareGate!.complete('private-meta');
      await operation;
      expect(repo.initializations, 0);
      expect(sdk.captured, 0);
      expect(sdk.aborted, 1);
    },
  );
  test(
    'account switch during init cannot open SDK with old certifyId',
    () async {
      repo.initGate = Completer<VerificationAttempt>();
      final operation = controller.start(identity);
      await tick();
      current = false;
      repo.initGate!.complete(attempt);
      await operation;
      expect(sdk.captured, 0);
      expect(repo.reads, 0);
      expect(repo.observed, isEmpty);
    },
  );
  test('dispose during SDK callback stops polling and observation', () async {
    sdk.captureGate = Completer<IdentityCaptureResult>();
    final operation = controller.start(identity);
    await tick();
    controller.dispose();
    sdk.captureGate!.complete(const IdentityCaptureResult(1000));
    await operation;
    expect(repo.reads, 0);
    expect(repo.observed, isEmpty);
    expect(controller.verifiedAttemptId, null);
  });
  test(
    'account changes while status request is pending cannot deliver PASS',
    () async {
      repo.readGate = Completer<VerificationSnapshot>();
      final operation = controller.start(identity);
      await tick();
      current = false;
      repo.readGate!.complete(snapshot(VerificationStatus.pass));
      await operation;
      expect(controller.verifiedAttemptId, null);
      expect(repo.observed, isEmpty);
    },
  );
  test('close during delay prevents next GET or observation', () async {
    controller.dispose();
    final wait = Completer<void>();
    controller = CloneVerificationController(
      repository: repo,
      capture: sdk,
      isCurrent: () => current,
      delay: (_) => wait.future,
    );
    repo.responses.add(snapshot(VerificationStatus.processing));
    final operation = controller.start(identity);
    await tick();
    controller.dispose();
    wait.complete();
    await operation;
    expect(repo.reads, 1);
    expect(repo.observed, isEmpty);
  });
}
