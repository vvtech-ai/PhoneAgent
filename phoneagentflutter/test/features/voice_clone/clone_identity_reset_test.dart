import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/identity/domain/identity_deletion_cleanup.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_identity_reset.dart';

void main() {
  test(
    'cleanup retries only failed steps without replaying deletion',
    () async {
      var deletes = 0, skipped = 0, clears = 0;
      final reset = CloneIdentityReset(
        delete: () async {
          deletes++;
        },
        isCurrent: () => true,
        createCleanup: () => IdentityDeletionCleanup(
          markSkipped: () async {
            skipped++;
          },
          clearRecording: () async {
            if (++clears == 1) throw StateError('synthetic');
          },
        ),
      );
      expect(await reset.run(), isFalse);
      expect(deletes, 1);
      expect(await reset.run(), isTrue);
      expect(deletes, 1);
      expect(skipped, 1);
      expect(clears, 2);
      expect(await reset.run(), isTrue);
      expect(
        deletes,
        2,
        reason: 'a later new reset must issue its own deletion',
      );
    },
  );
  test(
    'old account completion cannot clean a new account; requests deduplicate',
    () async {
      var current = true, deletes = 0, cleanups = 0;
      final pending = Completer<void>();
      final reset = CloneIdentityReset(
        delete: () {
          deletes++;
          return pending.future;
        },
        isCurrent: () => current,
        createCleanup: () {
          cleanups++;
          return IdentityDeletionCleanup(
            markSkipped: () async {},
            clearRecording: () async {},
          );
        },
      );
      final first = reset.run(), second = reset.run();
      expect(deletes, 1);
      current = false;
      pending.complete();
      expect(await first, isFalse);
      expect(await second, isFalse);
      expect(cleanups, 0);
    },
  );
  test(
    'remote failure performs no local cleanup and permits explicit retry',
    () async {
      var deletes = 0, cleanups = 0;
      final reset = CloneIdentityReset(
        delete: () async {
          if (++deletes == 1) throw StateError('synthetic');
        },
        isCurrent: () => true,
        createCleanup: () {
          cleanups++;
          return IdentityDeletionCleanup(
            markSkipped: () async {},
            clearRecording: () async {},
          );
        },
      );
      await expectLater(reset.run(), throwsStateError);
      expect(cleanups, 0);
      expect(await reset.run(), isTrue);
      expect(deletes, 2);
    },
  );
}
