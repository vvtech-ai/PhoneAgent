import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_archive_controller.dart';
import 'package:phone_agent/features/translation/domain/translation_archive.dart';
import 'package:phone_agent/features/translation/domain/recording/domestic_recording_attachment.dart';

class Store implements TranslationArchiveStore {
  List<TranslationArchiveEntry> entries = [];
  @override
  Future<List<TranslationArchiveEntry>> load() async => entries.toList();
  @override
  Future<void> save(List<TranslationArchiveEntry> values) async {
    entries = values.toList();
  }
}

class Gateway implements TranslationArchiveGateway {
  Gateway(this.store);
  final Store store;
  int calls = 0;
  @override
  Future<String> archive(TranslationArchiveEntry entry) async {
    if (entry.recordingPending) throw StateError('Recording still pending');
    expect(store.entries.single.recordingPending, false);
    calls++;
    return 'synthetic-server';
  }
}

void main() {
  TranslationArchiveEntry pending() => TranslationArchiveEntry(
    accountId: 'synthetic',
    clientCallId: 'synthetic-call',
    targetName: '合成',
    phone: '13800138000',
    myLanguage: 'zh',
    peerLanguage: 'en',
    route: TranslationArchiveRoute.domesticSip,
    connectedAt: 1000,
    endedAt: 1020,
    stage: TranslationArchiveStage.draining,
    recordingPending: true,
  );
  final attachment = DomesticRecordingAttachment(
    durationMillis: 20,
    checksumSha256: List.filled(64, 'a').join(),
  );
  test(
    'recovered pending capture resolves and persists metadata before archive upload',
    () async {
      final store = Store()..entries = [pending()];
      final gateway = Gateway(store);
      var prepares = 0;
      final controller = TranslationArchiveController(
        accountId: 'synthetic',
        store: store,
        gateway: gateway,
        isCurrent: () => true,
        prepareRecoveredRecording: (entry) async {
          prepares++;
          return entry.copy(recordingPending: false, recording: attachment);
        },
      );
      addTearDown(controller.dispose);
      await controller.recover();
      expect(prepares, 1);
      expect(gateway.calls, 1);
      expect(store.entries, isEmpty);
      expect(controller.snapshot.completed, 1);
    },
  );
  test(
    'live encoding is never mistaken for crashed capture on timer or retry',
    () async {
      final store = Store(), gateway = Gateway(Store());
      var prepares = 0;
      final controller = TranslationArchiveController(
        accountId: 'synthetic',
        store: store,
        gateway: gateway,
        isCurrent: () => true,
        drainDuration: Duration.zero,
        prepareRecoveredRecording: (entry) async {
          prepares++;
          return entry.copy(recordingPending: false);
        },
      );
      addTearDown(controller.dispose);
      controller.observe(pending());
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await controller.idle;
      await controller.retry();
      expect(prepares, 0);
      expect(controller.snapshot.pending, 1);
      expect(gateway.calls, 0);
    },
  );
}
