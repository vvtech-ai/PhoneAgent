import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/data/preview_translation_archive.dart';
import 'package:phone_agent/features/translation/domain/recording/domestic_recording_attachment.dart';
import 'package:phone_agent/features/translation/domain/translation_archive.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_archive_controller.dart';

class Store extends PreviewTranslationArchive {
  bool refuseRemoval = false;
  @override
  Future<void> save(List<TranslationArchiveEntry> entries) async {
    if (refuseRemoval && entries.isEmpty) throw StateError('synthetic disk');
    await super.save(entries);
  }
}

TranslationArchiveEntry entry() => TranslationArchiveEntry(
  accountId: 'synthetic',
  clientCallId: 'call-1',
  targetName: '合成',
  phone: '13800138000',
  myLanguage: 'zh',
  peerLanguage: 'en',
  route: TranslationArchiveRoute.domesticSip,
  connectedAt: 1000,
  endedAt: 2000,
  stage: TranslationArchiveStage.ready,
  recording: DomesticRecordingAttachment(
    durationMillis: 1000,
    checksumSha256: 'a' * 64,
  ),
);

void main() {
  test(
    'remote failure and durable pending removal failure retain files',
    () async {
      final store = Store()..failArchive = true;
      await store.save([entry()]);
      var cleanups = 0;
      final controller = TranslationArchiveController(
        accountId: 'synthetic',
        store: store,
        gateway: store,
        isCurrent: () => true,
        removeArchivedRecording: (_) async {
          expect(await store.load(), isEmpty);
          cleanups++;
        },
      );
      addTearDown(controller.dispose);
      await controller.recover();
      expect(cleanups, 0);
      store.failArchive = false;
      store.refuseRemoval = true;
      await controller.retry();
      expect(cleanups, 0);
      expect((await store.load()).length, 1);
      store.refuseRemoval = false;
      await controller.retry();
      expect(cleanups, 1);
      expect(controller.snapshot.completed, 1);
    },
  );
  test('cleanup failure never replays completed archive', () async {
    final store = Store();
    await store.save([entry()]);
    var cleanups = 0;
    final controller = TranslationArchiveController(
      accountId: 'synthetic',
      store: store,
      gateway: store,
      isCurrent: () => true,
      removeArchivedRecording: (_) async {
        expect(await store.load(), isEmpty);
        cleanups++;
        throw StateError('synthetic file failure');
      },
    );
    addTearDown(controller.dispose);
    await controller.recover();
    await controller.retry();
    expect(store.attempts, 1);
    expect(cleanups, 1);
    expect(controller.snapshot.completed, 1);
    expect(controller.snapshot.failed, false);
  });
}
