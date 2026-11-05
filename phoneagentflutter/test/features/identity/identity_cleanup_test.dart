import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/identity/domain/identity_profile.dart';
import 'package:phone_agent/features/identity/domain/identity_deletion_cleanup.dart';
import 'package:phone_agent/features/identity/presentation/controller/identity_controller.dart';

class CleanupIdentityRepository implements IdentityRepository {
  int deletes = 0;
  IdentityProfile profile = const IdentityProfile(
    accountId: 'synthetic',
    name: '合成身份',
  );
  @override
  Future<IdentityProfile> load() async => profile;
  @override
  Future<IdentityProfile> save(
    IdentityDraft draft, {
    required bool verified,
  }) async =>
      profile = IdentityProfile(accountId: 'synthetic', name: draft.name);
  @override
  Future<IdentityProfile> delete() async {
    deletes++;
    return profile = const IdentityProfile(accountId: 'synthetic');
  }
}

void main() {
  test('only failed local step repeats and DELETE stays at one', () async {
    var skips = 0, clears = 0;
    final repo = CleanupIdentityRepository();
    final controller = IdentityController(
      repo,
      createDeletionCleanup: () => IdentityDeletionCleanup(
        markSkipped: () async {
          skips++;
        },
        clearRecording: () async {
          if (++clears == 1) throw StateError('synthetic');
        },
      ),
    );
    addTearDown(controller.dispose);
    await controller.load();
    expect(await controller.delete(confirmed: true), IdentityOutcome.deleted);
    expect(controller.state.cleanupPending, true);
    controller.beginEdit();
    expect(controller.state.editing, false);
    expect(await controller.delete(confirmed: true), IdentityOutcome.rejected);
    await controller.load();
    expect(controller.state.cleanupPending, true);
    await controller.retryCleanup();
    expect(controller.state.cleanupPending, false);
    expect(controller.state.error, isEmpty);
    expect([repo.deletes, skips, clears], [1, 1, 2]);
    await controller.retryCleanup();
    expect(clears, 2);
    controller.beginEdit();
    expect(controller.state.editing, true);
  });
  test('another deletion receives a distinct cleanup job', () async {
    var jobs = 0, clears = 0;
    final controller = IdentityController(
      CleanupIdentityRepository(),
      createDeletionCleanup: () {
        jobs++;
        return IdentityDeletionCleanup(
          markSkipped: () async {},
          clearRecording: () async {
            clears++;
          },
        );
      },
    );
    addTearDown(controller.dispose);
    await controller.load();
    await controller.delete(confirmed: true);
    controller.beginEdit();
    controller.edit(name: '新身份');
    await controller.save();
    await controller.delete(confirmed: true);
    expect([jobs, clears], [2, 2]);
  });
  test(
    'job single flight attempts both independent steps before failing',
    () async {
      final pending = Completer<void>();
      var clears = 0, skips = 0;
      final job = IdentityDeletionCleanup(
        markSkipped: () async {
          skips++;
          throw StateError('synthetic');
        },
        clearRecording: () async {
          clears++;
          await pending.future;
        },
      );
      final first = job.run();
      expect(identical(first, job.run()), true);
      final expectation = expectLater(first, throwsStateError);
      pending.complete();
      await expectation;
      await expectLater(job.run(), throwsStateError);
      expect([skips, clears], [2, 1]);
    },
  );
  test(
    'disposed retry does not update state or repeat remote deletion',
    () async {
      final pending = Completer<void>();
      var calls = 0;
      final repo = CleanupIdentityRepository();
      final controller = IdentityController(
        repo,
        createDeletionCleanup: () => IdentityDeletionCleanup(
          markSkipped: () async {},
          clearRecording: () async {
            if (++calls == 1) throw StateError('synthetic');
            await pending.future;
          },
        ),
      );
      await controller.load();
      await controller.delete(confirmed: true);
      final retry = controller.retryCleanup();
      await controller.retryCleanup();
      controller.dispose();
      pending.complete();
      await retry;
      await controller.retryCleanup();
      expect([repo.deletes, calls], [1, 2]);
    },
  );
}
