import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/confirmation/confirmation_supplement.dart';
import 'package:phone_agent/features/conversation/domain/confirmation/confirmation_supplement_outbox.dart';

class _Store implements ConfirmationSupplementStore {
  List<ConfirmationSupplement> records = [];
  @override
  Future<List<ConfirmationSupplement>> read() async => records;
  @override
  Future<void> write(List<ConfirmationSupplement> records) async {
    this.records = records;
  }
}

class _Repository implements ConfirmationSupplementRepository {
  bool fail = true;
  Completer<void>? hold;
  final ids = <String>[];
  @override
  Future<String> save(String sessionId, ConfirmationSupplement record) async {
    ids.add(record.id);
    await hold?.future;
    if (fail) throw StateError('unavailable');
    return 'event-${record.id}';
  }
}

const record = ConfirmationSupplement(
  id: 'record',
  toolId: 'tool',
  userText: '稍后再打',
  assistantText: '暂不拨打',
);

void main() {
  test(
    'failure survives exit and re-entry with the same idempotent record identity',
    () async {
      final store = _Store(), repository = _Repository();
      final outbox = ConfirmationSupplementOutbox(
        sessionId: 's',
        store: store,
        repository: repository,
        onRecords: (_, __) {},
      );
      await outbox.add(record);
      expect(outbox.saveFailed, isTrue);
      expect(store.records.single.id, 'record');
      outbox.close();
      repository.fail = false;
      final restored = <ConfirmationSupplement>[];
      final next = ConfirmationSupplementOutbox(
        sessionId: 's',
        store: store,
        repository: repository,
        onRecords: (records, _) => restored.addAll(records),
      );
      await next.restore();
      expect(restored.first.id, 'record');
      expect(store.records, isEmpty);
      expect(repository.ids, ['record', 'record']);
      next.close();
    },
  );
  test(
    'closing on account change suppresses callbacks and retains uncertain pending save',
    () async {
      final store = _Store(),
          repository = _Repository()
            ..fail = false
            ..hold = Completer<void>();
      var updates = 0;
      final outbox = ConfirmationSupplementOutbox(
        sessionId: 's',
        store: store,
        repository: repository,
        onRecords: (_, __) => updates++,
      );
      final pending = outbox.add(record);
      await Future<void>.delayed(Duration.zero);
      outbox.close();
      final closedUpdates = updates;
      repository.hold!.complete();
      await pending;
      expect(updates, closedUpdates);
      expect(store.records.single.id, 'record');
    },
  );
}
