import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/voice_clone/data/certified_recording_codec.dart';
import 'package:phone_agent/features/voice_clone/data/certified_recording_repository.dart';
import 'package:phone_agent/features/voice_clone/domain/certified_recording_store.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_candidate.dart';
import 'clone_candidate_api_test.dart' show recordingFixture;

class MemoryRecordingBlobs implements CertifiedRecordingBlobStore {
  Uint8List? payload;
  Object? readFailure;
  bool failWrite = false, failClear = false;
  int writes = 0, clears = 0;
  @override
  Future<Uint8List?> read() async {
    if (readFailure != null) throw readFailure!;
    return payload;
  }

  @override
  Future<void> replace(Uint8List value) async {
    writes++;
    if (failWrite) throw StateError('synthetic disk failure');
    payload = Uint8List.fromList(value);
  }

  @override
  Future<void> clear() async {
    clears++;
    if (failClear) throw StateError('synthetic clear failure');
    payload = null;
  }
}

class _Download implements CertifiedRecordingDownload {
  Completer<Uint8List>? pending;
  bool fail = false;
  @override
  Future<Uint8List> download(CloneRecordingGrant _) async {
    if (fail) throw StateError('synthetic download failure');
    return pending == null ? recordingFixture().audio : pending!.future;
  }
}

CloneRecordingGrant _grant({String? hash}) {
  final value = recordingFixture();
  return CloneRecordingGrant(
    attemptId: 'attempt',
    grant: 'synthetic',
    receipt: value.receipt,
    audioSha256: hash ?? value.audioSha256,
    personFingerprint: value.personFingerprint,
    scriptVersion: value.scriptVersion,
    expiresAt: DateTime.utc(2030),
  );
}

void main() {
  late MemoryRecordingBlobs blobs;
  late _Download downloads;
  late CertifiedRecordingRepository repository;
  var current = true;
  setUp(() {
    current = true;
    blobs = MemoryRecordingBlobs();
    downloads = _Download();
    repository = CertifiedRecordingRepository(
      binding: 'dev/account',
      blobs: blobs,
      downloads: downloads,
      isCurrent: () => current,
    );
  });
  tearDown(() => repository.close());
  test(
    'prepared download never replaces old recording before commit or after cancel',
    () async {
      await repository.save(_grant());
      final old = blobs.payload;
      downloads.pending = Completer<Uint8List>();
      final prepared = repository.prepareSave(_grant());
      await Future<void>.delayed(Duration.zero);
      expect(blobs.writes, 1);
      prepared.cancel();
      downloads.pending!.complete(recordingFixture().audio);
      await prepared.commit();
      expect(blobs.payload, same(old));
      expect(blobs.writes, 1);
    },
  );
  test(
    'prepared commit survives route lifetime but rejects account changes',
    () async {
      downloads.pending = Completer<Uint8List>();
      final prepared = repository.prepareSave(_grant());
      current = false;
      downloads.pending!.complete(recordingFixture().audio);
      await expectLater(
        prepared.commit(),
        throwsA(RecordingStoreFailure.sessionChanged),
      );
      expect(blobs.writes, 0);
    },
  );
  test('prepared commit replaces only once', () async {
    final prepared = repository.prepareSave(_grant());
    await prepared.commit();
    await prepared.commit();
    expect(blobs.writes, 1);
  });

  test(
    'retryable clear retains newer successful recording from same-slot instance',
    () async {
      await repository.save(_grant());
      final clearOld = repository.prepareClear();
      blobs.failClear = true;
      await expectLater(clearOld(), throwsStateError);
      final other = CertifiedRecordingRepository(
        binding: repository.binding,
        blobs: blobs,
        downloads: downloads,
        isCurrent: () => current,
      );
      addTearDown(other.close);
      await other.save(_grant());
      final newer = blobs.payload;
      blobs.failClear = false;
      await clearOld();
      expect(blobs.payload, same(newer));
      expect(blobs.clears, 1);
    },
  );
  test(
    'retry clears old recording if a newer save failed, without repeating success',
    () async {
      await repository.save(_grant());
      final clearOld = repository.prepareClear();
      blobs.failClear = true;
      await expectLater(clearOld(), throwsStateError);
      blobs.failWrite = true;
      await expectLater(repository.save(_grant()), throwsStateError);
      blobs.failClear = false;
      await clearOld();
      await clearOld();
      expect(blobs.payload, isNull);
      expect(blobs.clears, 2);
    },
  );
  test(
    'clear boundary includes previously scheduled save, rejects replaced account',
    () async {
      downloads.pending = Completer<Uint8List>();
      final save = repository.save(_grant());
      final clearOld = repository.prepareClear();
      final clearing = clearOld();
      downloads.pending!.complete(recordingFixture().audio);
      await save;
      await clearing;
      expect(blobs.payload, isNull);
      current = false;
      await expectLater(
        repository.prepareClear()(),
        throwsA(RecordingStoreFailure.sessionChanged),
      );
      expect(blobs.clears, 1);
    },
  );
  test('save/read/clear uses validated shared recording payload', () async {
    expect((await repository.read()).recording, isNull);
    await repository.save(_grant());
    expect((await repository.read()).recording!.receipt, 'synthetic-receipt');
    await repository.clear();
    expect(blobs.payload, isNull);
  });
  test(
    'read waits for save and clear waits for both, no partial bytes',
    () async {
      downloads.pending = Completer<Uint8List>();
      final save = repository.save(_grant());
      final read = repository.read();
      final clear = repository.clear();
      await Future<void>.delayed(Duration.zero);
      expect(blobs.writes, 0);
      expect(blobs.clears, 0);
      downloads.pending!.complete(recordingFixture().audio);
      await save;
      expect((await read).recording, isNotNull);
      await clear;
      expect(blobs.payload, isNull);
    },
  );
  test(
    'same slot repositories share queue while different account slots differ',
    () async {
      final other = CertifiedRecordingRepository(
        binding: 'dev/account',
        blobs: blobs,
        downloads: downloads,
        isCurrent: () => current,
      );
      addTearDown(other.close);
      downloads.pending = Completer<Uint8List>();
      final save = repository.save(_grant());
      final clear = other.clear();
      downloads.pending!.complete(recordingFixture().audio);
      await save;
      await clear;
      expect(blobs.payload, isNull);
      expect(
        CertifiedRecordingRepository.slot('dev/account'),
        isNot(CertifiedRecordingRepository.slot('prod/account')),
      );
    },
  );
  for (final kind in ['download', 'hash', 'write']) {
    test(
      '$kind failure preserves previous bytes and queue remains usable',
      () async {
        await repository.save(_grant());
        final previous = blobs.payload;
        downloads.fail = kind == 'download';
        blobs.failWrite = kind == 'write';
        await expectLater(
          repository.save(_grant(hash: kind == 'hash' ? 'a' * 64 : null)),
          throwsA(anything),
        );
        expect(blobs.payload, same(previous));
        expect((await repository.read()).recording, isNotNull);
      },
    );
  }
  test(
    'corrupt encrypted blob or payload is cleared, not silently returned',
    () async {
      blobs.readFailure = RecordingStoreFailure.corrupt;
      expect((await repository.read()).invalid, true);
      blobs.readFailure = null;
      blobs.payload = Uint8List.fromList([1, 2, 3]);
      expect((await repository.read()).invalid, true);
      expect(blobs.clears, 2);
    },
  );
  test('wrong account or fingerprint clears only supplied slot', () async {
    blobs.payload = CertifiedRecordingCodec.encode('other', recordingFixture());
    expect((await repository.read()).invalid, true);
    await repository.save(_grant());
    expect(
      (await repository.read(personFingerprint: 'other-person')).invalid,
      true,
    );
    expect(blobs.clears, 2);
  });
  test(
    'temporary store failure never erases data or pretends absent',
    () async {
      await repository.save(_grant());
      blobs.readFailure = RecordingStoreFailure.unavailable;
      await expectLater(
        repository.read(),
        throwsA(RecordingStoreFailure.unavailable),
      );
      expect(blobs.clears, 0);
      expect(blobs.payload, isNotNull);
    },
  );
  test('failed invalid-data cleanup is surfaced, not marked cleared', () async {
    blobs.payload = Uint8List(1);
    blobs.failClear = true;
    await expectLater(repository.read(), throwsStateError);
    expect(blobs.payload, isNotNull);
  });
  for (final close in [false, true]) {
    test(
      'late download after ${close ? 'close' : 'account change'} does not store',
      () async {
        downloads.pending = Completer<Uint8List>();
        final save = repository.save(_grant());
        await Future<void>.delayed(Duration.zero);
        if (close) {
          repository.close();
        } else {
          current = false;
        }
        downloads.pending!.complete(recordingFixture().audio);
        await expectLater(save, throwsA(RecordingStoreFailure.sessionChanged));
        expect(blobs.writes, 0);
      },
    );
  }
}
