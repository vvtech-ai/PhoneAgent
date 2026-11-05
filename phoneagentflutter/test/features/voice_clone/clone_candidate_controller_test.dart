import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_candidate.dart';
import 'package:phone_agent/features/voice_clone/presentation/controller/clone_candidate_controller.dart';
import 'clone_candidate_api_test.dart' show recordingFixture;

const _model = 'QWEN_OMNI_PLUS';
CloneCandidate _candidate({
  String id = 'candidate-1',
  String model = _model,
  CloneCandidateStatus status = CloneCandidateStatus.ready,
  CloneCandidateSource source = CloneCandidateSource.verification,
  CloneBillingStatus billing = CloneBillingStatus.charged,
}) => CloneCandidate(
  id: id,
  modelId: model,
  status: status,
  source: source,
  billing: billing,
);

class _Repository implements CloneCandidateRepository {
  int creates = 0, reads = 0;
  final keys = <String>[];
  final results = <CloneCandidate>[];
  Completer<CloneGeneratedCandidate>? pendingCreate;
  Completer<CloneCandidate>? pendingRead;
  bool failCreate = false, failRead = false;
  Object? createError;
  CloneGeneratedCandidate generated = CloneGeneratedCandidate(_candidate());
  Future<CloneGeneratedCandidate> _create(String key) async {
    creates++;
    keys.add(key);
    if (createError != null) throw createError!;
    if (failCreate) throw StateError('synthetic unknown outcome');
    return pendingCreate == null ? generated : pendingCreate!.future;
  }

  @override
  Future<CloneGeneratedCandidate> fromVerification(
    String m,
    String a,
    String r,
  ) => _create(r);
  @override
  Future<CloneGeneratedCandidate> fromRecording(
    String m,
    CertifiedCloneRecording a,
    String r,
  ) => _create(r);
  @override
  Future<CloneCandidate> read(String m) async {
    reads++;
    if (failRead) throw StateError('synthetic unavailable');
    if (pendingRead != null) return pendingRead!.future;
    return results.isEmpty ? generated.candidate : results.removeAt(0);
  }
}

void main() {
  late _Repository repository;
  late CloneCandidateController controller;
  setUp(() {
    repository = _Repository();
    controller = CloneCandidateController(
      repository: repository,
      modelId: _model,
      maxPolls: 3,
      delay: (_) async {},
    );
  });
  tearDown(() {
    if (controller.mounted) controller.dispose();
  });
  testWidgets('late READY after short limit updates without another create', (
    tester,
  ) async {
    repository.generated = CloneGeneratedCandidate(
      _candidate(status: CloneCandidateStatus.processing),
    );
    await controller.createFromVerification('attempt', 'request');
    expect(controller.state.issue, CandidateIssue.pollLimit);
    final before = repository.reads;
    repository.generated = CloneGeneratedCandidate(_candidate());
    await tester.pump(const Duration(seconds: 15));
    expect(controller.state.candidate!.ready, true);
    expect(repository.reads, before + 1);
    expect(repository.creates, 1);
    await tester.pump(const Duration(seconds: 30));
    expect(repository.reads, before + 1);
  });
  testWidgets('background errors recover and disposal cancels observation', (
    tester,
  ) async {
    repository.generated = CloneGeneratedCandidate(
      _candidate(status: CloneCandidateStatus.processing),
    );
    await controller.synchronize();
    repository.failRead = true;
    await tester.pump(const Duration(seconds: 15));
    expect(controller.state.issue, CandidateIssue.requestFailed);
    repository.failRead = false;
    repository.generated = CloneGeneratedCandidate(_candidate());
    await tester.pump(const Duration(seconds: 15));
    expect(controller.state.candidate!.ready, true);
    controller.dispose();
    final reads = repository.reads;
    await tester.pump(const Duration(seconds: 30));
    expect(repository.reads, reads);
  });
  testWidgets('account invalidation stops background reads', (tester) async {
    controller.dispose();
    var current = true;
    controller = CloneCandidateController(
      repository: repository,
      modelId: _model,
      maxPolls: 1,
      delay: (_) async {},
      isCurrent: () => current,
    );
    repository.generated = CloneGeneratedCandidate(
      _candidate(status: CloneCandidateStatus.processing),
    );
    await controller.synchronize();
    current = false;
    final reads = repository.reads;
    await tester.pump(const Duration(seconds: 15));
    expect(repository.reads, reads);
  });
  test(
    'expired identity requests reauthentication, never retries generation',
    () async {
      repository.createError = CloneGenerationFailure.identityExpired;
      await controller.createFromRecording(recordingFixture(), 'request');
      expect(controller.state.issue, CandidateIssue.identityExpired);
      expect(controller.state.creationUncertain, false);
      await controller.synchronize();
      await controller.createFromRecording(recordingFixture(), 'new-key');
      expect(repository.creates, 1);
      expect(repository.reads, 0);
    },
  );
  test(
    'native missing candidate ID does not make an accepted generation unknown',
    () async {
      repository.generated = CloneGeneratedCandidate(
        _candidate(id: '', status: CloneCandidateStatus.processing),
      );
      repository.failRead = true;
      await controller.createFromVerification('attempt', 'request');
      expect(controller.state.candidate, isNotNull);
      expect(controller.state.phase, CandidatePhase.needsSync);
      expect(controller.state.creationUncertain, false);
      expect(repository.creates, 1);
    },
  );
  test(
    'single ready generation neither polls nor permits duplicate create',
    () async {
      await controller.createFromVerification('attempt', 'request');
      await controller.createFromVerification('attempt', 'another-request');
      expect(repository.creates, 1);
      expect(repository.keys, ['request']);
      expect(repository.reads, 0);
      expect(controller.state.candidate!.ready, true);
      expect(controller.state.creationUncertain, false);
    },
  );
  test(
    'recording path stays recording and creation material absent from state',
    () async {
      repository.generated = CloneGeneratedCandidate(
        _candidate(source: CloneCandidateSource.localRecording),
      );
      await controller.createFromRecording(recordingFixture(), 'request');
      expect(
        controller.state.candidate!.source,
        CloneCandidateSource.localRecording,
      );
      expect(controller.recordingGrant, isNull);
    },
  );
  test('processing polls to READY CHARGED using same candidate', () async {
    repository.generated = CloneGeneratedCandidate(
      _candidate(status: CloneCandidateStatus.processing),
    );
    repository.results.addAll([
      _candidate(status: CloneCandidateStatus.processing),
      _candidate(),
    ]);
    await controller.createFromVerification('attempt', 'request');
    expect(repository.reads, 2);
    expect(controller.state.phase, CandidatePhase.settled);
    expect(controller.state.candidate!.ready, true);
  });
  test('poll exhaustion keeps processing fact and retry only reads', () async {
    repository.generated = CloneGeneratedCandidate(
      _candidate(status: CloneCandidateStatus.processing),
    );
    await controller.createFromVerification('attempt', 'request');
    expect(repository.reads, 3);
    expect(controller.state.issue, CandidateIssue.pollLimit);
    expect(controller.state.candidate!.processing, true);
    repository.results.add(_candidate());
    await controller.synchronize();
    expect(repository.creates, 1);
    expect(controller.state.candidate!.ready, true);
  });
  test(
    'unknown generation does not claim latest GET proves the operation',
    () async {
      repository.failCreate = true;
      await controller.createFromVerification('attempt', 'request');
      expect(controller.state.creationUncertain, true);
      await controller.createFromVerification('attempt', 'new-key');
      await controller.synchronize();
      expect(repository.creates, 1);
      expect(repository.reads, 1);
      expect(controller.state.creationUncertain, true);
      expect(controller.state.candidate!.ready, true);
    },
  );
  test(
    'opening an existing candidate is reads only and disables new create',
    () async {
      await controller.synchronize();
      await controller.createFromVerification('attempt', 'request');
      expect(repository.reads, 1);
      expect(repository.creates, 0);
      expect(controller.state.creationUncertain, false);
    },
  );
  for (final mismatch in ['model', 'id']) {
    test(
      'poll rejects changed candidate $mismatch without replacing known one',
      () async {
        repository.generated = CloneGeneratedCandidate(
          _candidate(status: CloneCandidateStatus.processing),
        );
        repository.results.add(
          _candidate(
            id: mismatch == 'id' ? 'candidate-2' : 'candidate-1',
            model: mismatch == 'model' ? 'DOUBAO_SEEDUPLEX_3_0' : _model,
            source: mismatch == 'source'
                ? CloneCandidateSource.localRecording
                : CloneCandidateSource.verification,
          ),
        );
        await controller.createFromVerification('attempt', 'request');
        expect(controller.state.phase, CandidatePhase.conflict);
        expect(controller.state.candidate!.id, 'candidate-1');
        await controller.synchronize();
        expect(repository.reads, 1);
      },
    );
  }
  test('FAILED and uncharged READY cannot become usable candidate', () async {
    repository.generated = CloneGeneratedCandidate(
      _candidate(status: CloneCandidateStatus.failed),
    );
    await controller.synchronize();
    expect(controller.state.candidate!.ready, false);
    repository.generated = CloneGeneratedCandidate(
      _candidate(billing: CloneBillingStatus.reserved),
    );
    await controller.synchronize();
    expect(controller.state.candidate!.ready, false);
  });
  test('read failure retains candidate and does not re-create', () async {
    repository.generated = CloneGeneratedCandidate(
      _candidate(status: CloneCandidateStatus.processing),
    );
    repository.failRead = true;
    await controller.createFromVerification('attempt', 'request');
    expect(controller.state.issue, CandidateIssue.requestFailed);
    expect(controller.state.candidate!.processing, true);
    expect(controller.state.creationUncertain, false);
  });
  test('busy creation and sync cannot overlap', () async {
    repository.pendingCreate = Completer<CloneGeneratedCandidate>();
    final run = controller.createFromVerification('attempt', 'request');
    await controller.synchronize();
    await controller.createFromVerification('attempt', 'repeat');
    expect(repository.creates, 1);
    expect(repository.reads, 0);
    repository.pendingCreate!.complete(repository.generated);
    await run;
  });
  test(
    'dispose while generation pending suppresses polling and sensitive grant',
    () async {
      repository.pendingCreate = Completer<CloneGeneratedCandidate>();
      final run = controller.createFromVerification('attempt', 'request');
      controller.dispose();
      repository.pendingCreate!.complete(
        CloneGeneratedCandidate(
          _candidate(status: CloneCandidateStatus.processing),
        ),
      );
      await run;
      expect(repository.reads, 0);
      expect(controller.recordingGrant, isNull);
    },
  );
  test('dispose during poll interval prevents next GET', () async {
    controller.dispose();
    final waiting = Completer<void>();
    controller = CloneCandidateController(
      repository: repository,
      modelId: _model,
      delay: (_) => waiting.future,
    );
    repository.generated = CloneGeneratedCandidate(
      _candidate(status: CloneCandidateStatus.processing),
    );
    final run = controller.createFromVerification('attempt', 'request');
    await Future<void>.delayed(Duration.zero);
    controller.dispose();
    waiting.complete();
    await run;
    expect(repository.reads, 0);
  });
  test('dispose during read ignores late response and further polls', () async {
    repository.pendingRead = Completer<CloneCandidate>();
    final run = controller.synchronize();
    controller.dispose();
    repository.pendingRead!.complete(
      _candidate(status: CloneCandidateStatus.processing),
    );
    await run;
    expect(repository.reads, 1);
  });
}
