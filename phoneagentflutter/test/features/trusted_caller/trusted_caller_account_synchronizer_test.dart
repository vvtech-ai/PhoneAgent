import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/trusted_caller/domain/trusted_caller.dart';
import 'package:phone_agent/features/trusted_caller/domain/trusted_caller_account.dart';
import 'package:phone_agent/features/trusted_caller/domain/trusted_caller_account_synchronizer.dart';

class PendingPort implements TrustedCallerAccountPort {
  final owners = <TrustedCallerOwner?>[];
  final replies = <Completer<bool>>[];
  @override
  Future<bool> updateAccount(TrustedCallerOwner? owner, String environment) {
    owners.add(owner);
    final reply = Completer<bool>();
    replies.add(reply);
    return reply.future;
  }
}

Future<void> flush() => Future<void>.delayed(Duration.zero);
void main() {
  const first = TrustedCallerOwner('first', 'synthetic', 1);
  const second = TrustedCallerOwner('second', 'synthetic', 2);
  test(
    'serializes replacement, rejects stale success and deduplicates entry',
    () async {
      final port = PendingPort();
      final sync = TrustedCallerAccountSynchronizer(port);
      final old = sync.select(first, 'test');
      await flush();
      final current = sync.select(second, 'test');
      expect(identical(current, sync.ensure(second, 'test')), true);
      expect(port.owners, [first]);
      port.replies.first.complete(true);
      expect(await old, false);
      await flush();
      expect(port.owners, [first, second]);
      port.replies.last.complete(true);
      expect(await current, true);
      expect(await sync.ensure(second, 'test'), true);
      expect(port.owners.length, 2);
      sync.close();
    },
  );
  test(
    'failed delivery retries; logout supersedes queued account; close invalidates',
    () async {
      final port = PendingPort();
      final sync = TrustedCallerAccountSynchronizer(port);
      final failed = sync.select(first, 'test');
      await flush();
      port.replies.last.complete(false);
      expect(await failed, false);
      final retry = sync.ensure(first, 'test');
      await flush();
      final skipped = sync.select(second, 'test');
      final logout = sync.select(null, 'test');
      port.replies.last.complete(true);
      expect(await retry, false);
      expect(await skipped, false);
      await flush();
      expect(port.owners, [first, first, null]);
      sync.close();
      port.replies.last.complete(true);
      expect(await logout, false);
      expect(await sync.ensure(null, 'test'), false);
    },
  );
}
