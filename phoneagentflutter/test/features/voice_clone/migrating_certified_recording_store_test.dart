import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/voice_clone/data/certified_recording_codec.dart';
import 'package:phone_agent/features/voice_clone/data/certified_recording_repository.dart';
import 'package:phone_agent/features/voice_clone/data/migrating_certified_recording_store.dart';
import 'package:phone_agent/features/voice_clone/domain/certified_recording_store.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_candidate.dart';
import 'certified_recording_repository_test.dart' show MemoryRecordingBlobs;
import 'clone_candidate_api_test.dart' show recordingFixture;

class _Download implements CertifiedRecordingDownload {
  @override
  Future<Uint8List> download(CloneRecordingGrant _) async =>
      recordingFixture().audio;
}

CloneRecordingGrant _grant() {
  final recording = recordingFixture();
  return CloneRecordingGrant(
    attemptId: 'synthetic',
    grant: 'synthetic',
    receipt: 'new-receipt',
    audioSha256: recording.audioSha256,
    personFingerprint: recording.personFingerprint,
    scriptVersion: recording.scriptVersion,
    expiresAt: DateTime.utc(2030),
  );
}

void main() {
  late MemoryRecordingBlobs target;
  late CertifiedRecordingRepository repository;
  late Future<CertifiedCloneRecording?> Function() legacy;
  var current = true;
  var reads = 0;
  var sequence = 0;
  late String binding;
  CertifiedRecordingRepository create() {
    final repo = CertifiedRecordingRepository(
      binding: binding,
      blobs: MigratingCertifiedRecordingStore(
        target: target,
        binding: binding,
        isCurrent: () => current,
        readLegacy: () {
          reads++;
          return legacy();
        },
      ),
      downloads: _Download(),
      isCurrent: () => current,
    );
    addTearDown(repo.close);
    return repo;
  }

  setUp(() {
    target = MemoryRecordingBlobs();
    current = true;
    reads = 0;
    binding = 'prod/synthetic-${sequence++}';
    legacy = () async => recordingFixture();
    repository = create();
  });

  test(
    'first import writes validated new format and restart gives new priority',
    () async {
      final first = await repository.read();
      expect(first.recording!.receipt, 'synthetic-receipt');
      expect(
        CertifiedRecordingCodec.decode(binding, target.payload!).audio,
        recordingFixture().audio,
      );
      expect((await create().read()).recording!.receipt, 'synthetic-receipt');
      expect(reads, 1);
      expect(target.writes, 1);
      expect(target.clears, 0);
    },
  );
  test('already saved new recording never opens legacy source', () async {
    await repository.save(_grant());
    expect((await create().read()).recording!.receipt, 'new-receipt');
    expect(reads, 0);
  });
  test('absent legacy source is marked once across restart', () async {
    legacy = () async => null;
    expect((await repository.read()).recording, isNull);
    expect(target.payload, isNotNull);
    expect((await create().read()).recording, isNull);
    expect(reads, 1);
    expect(target.writes, 1);
  });
  test(
    'clear before first read blocks import, new save replaces empty marker',
    () async {
      await repository.clear();
      expect((await create().read()).recording, isNull);
      expect(reads, 0);
      expect(target.clears, 0);
      await repository.save(_grant());
      expect((await create().read()).recording!.receipt, 'new-receipt');
      expect(reads, 0);
    },
  );
  test(
    'clear after import prevents resurrection across rebuilt repositories',
    () async {
      await repository.read();
      await repository.clear();
      expect((await create().read()).recording, isNull);
      expect(reads, 1);
      expect(target.clears, 0);
    },
  );
  test(
    'corrupt new payload is invalidated without falling back to legacy',
    () async {
      target.payload = Uint8List.fromList([1, 2, 3]);
      expect((await repository.read()).invalid, isTrue);
      expect((await create().read()).recording, isNull);
      expect(reads, 0);
      expect(target.clears, 0);
    },
  );
  test('new read failure never reads old source or clears target', () async {
    target.readFailure = RecordingStoreFailure.unavailable;
    await expectLater(
      repository.read(),
      throwsA(RecordingStoreFailure.unavailable),
    );
    expect(reads, 0);
    expect(target.writes, 0);
    expect(target.clears, 0);
  });
  test(
    'legacy unavailable remains retryable without writing an empty marker',
    () async {
      legacy = () async => throw RecordingStoreFailure.unavailable;
      await expectLater(
        repository.read(),
        throwsA(RecordingStoreFailure.unavailable),
      );
      expect(target.payload, isNull);
      expect(target.writes, 0);
      legacy = () async => recordingFixture();
      expect((await repository.read()).recording, isNotNull);
      expect(reads, 2);
    },
  );
  test(
    'legacy corruption writes invalid marker but has no legacy delete operation',
    () async {
      legacy = () async => throw RecordingStoreFailure.corrupt;
      expect((await repository.read()).invalid, isTrue);
      expect((await create().read()).recording, isNull);
      expect(reads, 1);
      expect(target.clears, 0);
    },
  );
  test(
    'failed target write never reports migration success and can retry',
    () async {
      target.failWrite = true;
      await expectLater(repository.read(), throwsStateError);
      expect(target.payload, isNull);
      target.failWrite = false;
      expect((await repository.read()).recording, isNotNull);
      expect(reads, 2);
    },
  );
  test('late legacy result after account change cannot write target', () async {
    final entered = Completer<void>();
    final pending = Completer<CertifiedCloneRecording?>();
    legacy = () {
      entered.complete();
      return pending.future;
    };
    final read = repository.read();
    final rejected = expectLater(
      read,
      throwsA(RecordingStoreFailure.sessionChanged),
    );
    await entered.future;
    current = false;
    pending.complete(recordingFixture());
    await rejected;
    expect(target.writes, 0);
    expect(target.payload, isNull);
  });
  test(
    'concurrent instances serialize import then new save then clear',
    () async {
      final entered = Completer<void>();
      final pending = Completer<CertifiedCloneRecording?>();
      legacy = () {
        entered.complete();
        return pending.future;
      };
      final read = repository.read();
      await entered.future;
      final other = create();
      final save = other.save(_grant());
      final afterSave = repository.read();
      final clear = other.clear();
      expect(target.writes, 0);
      pending.complete(recordingFixture());
      expect((await read).recording!.receipt, 'synthetic-receipt');
      await save;
      expect((await afterSave).recording!.receipt, 'new-receipt');
      await clear;
      expect((await create().read()).recording, isNull);
      expect(reads, 1);
      expect(target.writes, 3);
    },
  );
  test('failed clear retry cannot erase a newer successful save', () async {
    await repository.read();
    final clearOld = repository.prepareClear();
    target.failWrite = true;
    await expectLater(clearOld(), throwsStateError);
    target.failWrite = false;
    await create().save(_grant());
    await clearOld();
    expect((await repository.read()).recording!.receipt, 'new-receipt');
    expect(reads, 1);
  });
  test(
    'failed empty marker is retried rather than reporting absence',
    () async {
      legacy = () async => null;
      target.failWrite = true;
      await expectLater(repository.read(), throwsStateError);
      target.failWrite = false;
      expect((await repository.read()).recording, isNull);
      expect(reads, 2);
      expect(target.payload, isNotNull);
    },
  );
}
