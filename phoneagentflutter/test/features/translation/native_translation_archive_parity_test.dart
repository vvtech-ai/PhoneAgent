import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/data/preview_translation_archive.dart';
import 'package:phone_agent/features/translation/data/translation_archive_codec.dart';
import 'package:phone_agent/features/translation/domain/translation_archive.dart';
import 'package:phone_agent/features/translation/domain/recording/domestic_recording_attachment.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_archive_controller.dart';

class _Store extends PreviewTranslationArchive {
  bool refuseRemoval = false, refuseCheckpoint = false;
  List<TranslationArchiveEntry> get entries =>
      TranslationArchiveCodec.decode('preview', 'synthetic', journal);
  @override
  Future<void> save(List<TranslationArchiveEntry> entries) async {
    if (refuseRemoval && entries.isEmpty ||
        refuseCheckpoint &&
            entries.any(
              (e) => e.stage == TranslationArchiveStage.recordingUpload,
            )) {
      throw StateError('synthetic storage failure');
    }
    await super.save(entries);
  }
}

class _Gateway implements TranslationArchivePhasedGateway {
  _Gateway(this.store);
  final _Store store;
  int creates = 0, uploads = 0;
  bool failUpload = false;
  final uploadedIds = <String>[];
  void Function()? afterCreate;
  @override
  Future<String> archive(TranslationArchiveEntry entry) =>
      throw StateError('Must use staged gateway');
  @override
  Future<String> createRecord(TranslationArchiveEntry entry) async {
    creates++;
    expect(entry.recordingPending, false);
    afterCreate?.call();
    return 'server-synthetic';
  }

  @override
  Future<void> uploadRecording(
    TranslationArchiveEntry entry,
    String serverCallId,
  ) async {
    uploads++;
    uploadedIds.add(serverCallId);
    expect(store.entries.single.serverCallId, serverCallId);
    expect(store.entries.single.stage, TranslationArchiveStage.recordingUpload);
    if (failUpload) throw StateError('synthetic upload failure');
  }
}

TranslationArchiveEntry _entry({
  bool pending = false,
  bool missing = false,
  TranslationArchiveStage stage = TranslationArchiveStage.draining,
}) => TranslationArchiveEntry(
  accountId: 'synthetic',
  clientCallId: 'call-synthetic',
  targetName: '合成',
  phone: '10086',
  myLanguage: 'zh',
  peerLanguage: 'en',
  route: TranslationArchiveRoute.domesticSip,
  connectedAt: 1000,
  endedAt: 2000,
  stage: stage,
  recordingPending: pending,
  recording: pending || missing
      ? null
      : DomesticRecordingAttachment(
          durationMillis: 1000,
          checksumSha256: 'a' * 64,
        ),
);
TranslationArchiveController _owner(
  _Store store,
  _Gateway gateway, {
  bool Function()? current,
  void Function(String, Object)? onFailure,
  Future<TranslationArchiveEntry> Function(TranslationArchiveEntry)? recover,
  Future<void> Function(TranslationArchiveEntry)? cleanup,
}) => TranslationArchiveController(
  accountId: 'synthetic',
  store: store,
  gateway: gateway,
  isCurrent: current ?? () => true,
  onFailure: onFailure,
  prepareRecoveredRecording: recover,
  removeArchivedRecording: cleanup,
);

void main() {
  for (final milliseconds in [540, 775, 1500]) {
    test(
      'recording ${milliseconds}ms waits normally, then drains once and automatically archives',
      () => fakeAsync((clock) {
        final store = _Store();
        final actual = _Gateway(store);
        final controller = _owner(store, actual);
        controller.observe(_entry(pending: true));
        clock.flushMicrotasks();
        clock.elapse(Duration(milliseconds: milliseconds));
        clock.flushMicrotasks();
        expect(controller.snapshot.failed, false);
        expect(controller.snapshot.pending, 1);
        expect(actual.creates, 0);
        controller.observe(_entry());
        clock.flushMicrotasks();
        clock.elapse(const Duration(milliseconds: 499));
        expect(actual.creates, 0);
        clock.elapse(const Duration(milliseconds: 1));
        clock.flushMicrotasks();
        expect(actual.creates, 1);
        expect(actual.uploads, 1);
        expect(controller.snapshot.completed, 1);
        expect(controller.snapshot.failed, false);
        expect(store.entries, isEmpty);
        controller.observe(_entry());
        clock.flushMicrotasks();
        expect(actual.creates, 1);
        expect(clock.pendingTimers, isEmpty);
        controller.dispose();
      }),
    );
  }
  test(
    'legacy already-sealed live recording resumes once when encoding completes',
    () async {
      final store = _Store();
      final gateway = _Gateway(store);
      final owner = _owner(store, gateway);
      owner.observe(
        _entry(pending: true, stage: TranslationArchiveStage.ready),
      );
      await owner.idle;
      await owner.retry();
      expect(owner.snapshot.failed, false);
      expect(gateway.creates, 0);
      owner.observe(_entry(stage: TranslationArchiveStage.ready));
      await owner.idle;
      expect(gateway.creates, 1);
      expect(gateway.uploads, 1);
      owner.observe(_entry(stage: TranslationArchiveStage.ready));
      await owner.idle;
      expect(gateway.creates, 1);
      owner.dispose();
    },
  );
  test(
    'failed upload persists server ID; restarted owner uploads without creating again',
    () async {
      final store = _Store();
      await store.save([_entry(stage: TranslationArchiveStage.ready)]);
      final gateway = _Gateway(store)..failUpload = true;
      final failures = <String>[];
      final first = _owner(
        store,
        gateway,
        onFailure: (stage, _) => failures.add(stage),
      );
      await first.recover();
      expect(gateway.creates, 1);
      expect(gateway.uploads, 1);
      expect(first.snapshot.failed, true);
      expect(failures, ['recordingUpload']);
      expect(store.entries.single.serverCallId, 'server-synthetic');
      expect(
        store.entries.single.stage,
        TranslationArchiveStage.recordingUpload,
      );
      first.dispose();
      final secondGateway = _Gateway(store);
      final second = _owner(store, secondGateway);
      await second.recover();
      expect(secondGateway.creates, 0);
      expect(secondGateway.uploads, 1);
      expect(secondGateway.uploadedIds, ['server-synthetic']);
      expect(store.entries, isEmpty);
      second.dispose();
    },
  );
  test(
    'failed checkpoint save retains in-memory receipt and never uploads before saving',
    () async {
      final store = _Store();
      await store.save([_entry(stage: TranslationArchiveStage.ready)]);
      store.refuseCheckpoint = true;
      final gateway = _Gateway(store);
      final owner = _owner(store, gateway);
      await owner.recover();
      expect(gateway.creates, 1);
      expect(gateway.uploads, 0);
      expect(owner.snapshot.failed, true);
      store.refuseCheckpoint = false;
      await owner.retry();
      expect(gateway.creates, 1);
      expect(gateway.uploads, 1);
      expect(store.entries, isEmpty);
      owner.dispose();
    },
  );
  test(
    'remote completion followed by removal failure recovers only local commit and cleanup',
    () async {
      final store = _Store();
      await store.save([_entry(stage: TranslationArchiveStage.ready)]);
      store.refuseRemoval = true;
      var cleaned = 0;
      final gateway = _Gateway(store);
      final owner = _owner(
        store,
        gateway,
        cleanup: (_) async {
          cleaned++;
        },
      );
      await owner.recover();
      expect(store.entries.single.stage, TranslationArchiveStage.completed);
      expect(cleaned, 0);
      owner.dispose();
      store.refuseRemoval = false;
      final nextGateway = _Gateway(store);
      final next = _owner(
        store,
        nextGateway,
        cleanup: (_) async {
          cleaned++;
        },
      );
      await next.recover();
      expect(nextGateway.creates, 0);
      expect(nextGateway.uploads, 0);
      expect(cleaned, 1);
      expect(store.entries, isEmpty);
      next.dispose();
    },
  );
  test(
    'legacy v1 pending recording recovers before upsert and uploads using checkpoint',
    () async {
      final store = _Store();
      await store.save([
        _entry(pending: true, stage: TranslationArchiveStage.ready),
      ]);
      expect(store.journal, isNot(contains('serverCallId')));
      final gateway = _Gateway(store);
      var prepared = 0;
      final owner = _owner(
        store,
        gateway,
        recover: (entry) async {
          prepared++;
          return entry.copy(
            recordingPending: false,
            recording: _entry().recording,
          );
        },
      );
      await owner.recover();
      expect(prepared, 1);
      expect(gateway.creates, 1);
      expect(gateway.uploads, 1);
      expect(store.entries, isEmpty);
      owner.dispose();
    },
  );
  test(
    'encoding unavailable still creates record without fabricated attachment',
    () async {
      final store = _Store();
      await store.save([
        _entry(missing: true, stage: TranslationArchiveStage.ready),
      ]);
      final gateway = _Gateway(store);
      final owner = _owner(store, gateway);
      await owner.recover();
      expect(gateway.creates, 1);
      expect(gateway.uploads, 1);
      expect(owner.snapshot.failed, false);
      expect(store.entries, isEmpty);
      owner.dispose();
    },
  );
  test(
    'logout during create forbids recording upload and completion',
    () async {
      final store = _Store();
      await store.save([_entry(stage: TranslationArchiveStage.ready)]);
      var current = true;
      final gateway = _Gateway(store)
        ..afterCreate = () {
          current = false;
        };
      final owner = _owner(store, gateway, current: () => current);
      await owner.recover();
      expect(gateway.uploads, 0);
      expect(owner.snapshot.completed, 0);
      expect(store.entries, hasLength(1));
      owner.dispose();
    },
  );
}
