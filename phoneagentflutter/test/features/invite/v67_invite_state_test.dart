import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/invite/domain/invite.dart';
import 'package:phone_agent/features/invite/domain/invite_entry_presentation.dart';
import 'package:phone_agent/features/invite/presentation/controller/invite_records_controller.dart';
import 'invite_fakes.dart';

class RecordsRepo extends FakeInviteRepository {
  Completer<InviteRecords>? pending;
  bool failRecords = false;
  @override
  Future<InviteRecords> records([String? cursor]) async {
    if (pending != null) return pending!.future;
    if (failRecords) throw const InviteFailure('NETWORK');
    return InviteRecords(
      [
        const InviteRecord('r1', '138****0000', '2026-10-12', 10),
        if (cursor != null)
          const InviteRecord('r2', '138****0001', '2026-10-12', 20),
      ],
      2,
      cursor == null ? 'next' : null,
    );
  }
}

void main() {
  test('entry equal eligible reward only, missing activity hides', () {
    expect(InviteEntryPresentation.fromOverview(null).visible, false);
    final equal = InviteEntryPresentation.fromOverview(
      const InviteOverview(
        sampleActivity,
        InvitePersonal(true, 0, 20, 0, false),
      ),
    );
    expect(equal.visible, true);
    expect(equal.subtitle, contains('双方各得 20'));
    final zero = InviteEntryPresentation.fromOverview(
      const InviteOverview(
        sampleActivity,
        InvitePersonal(false, 0, 0, 0, false),
      ),
    );
    expect(zero.subtitle, contains('以活动规则为准'));
  });
  test(
    'records pagination deduplicates and failure retains cursor and rows',
    () async {
      final repo = RecordsRepo();
      final c = InviteRecordsController(repo);
      await c.refresh();
      repo.failRecords = true;
      await c.loadNext();
      expect(c.state.items.single.id, 'r1');
      expect(c.state.cursor, 'next');
      repo.failRecords = false;
      await c.loadNext();
      expect(c.state.items.map((r) => r.id), ['r1', 'r2']);
      expect(c.state.cursor, isNull);
      await c.refresh();
      expect(c.state.items.length, 1);
      c.dispose();
    },
  );
  test('old account records cannot publish after disposal', () async {
    final repo = RecordsRepo()..pending = Completer();
    final c = InviteRecordsController(repo);
    final request = c.refresh();
    c.dispose();
    repo.pending!.complete(const InviteRecords([], 0, null));
    await request;
  });
}
