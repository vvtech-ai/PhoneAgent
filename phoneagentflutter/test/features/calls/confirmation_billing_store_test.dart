import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/calls/domain/confirmation_billing.dart';
import 'package:phone_agent/features/calls/data/secure_confirmation_billing_store.dart';
import '../translation/legacy_location_storage_test.dart'
    show ControlledStorage;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final request = ConfirmationBillingRequest('s', ['tool', 'stable']);
  const old = ConfirmationBillingSnapshot(
    modelTitle: 'Doubao',
    availableBalance: 100,
  );
  const current = ConfirmationBillingSnapshot(
    modelTitle: 'Qwen',
    availableBalance: 9999,
  );
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'nonpending batch with no history never captures current or saves a placeholder',
    () async {
      final closed = ConfirmationBillingRequest('s', [
        'batch-plus:x:1',
      ], captureCurrent: false);
      final pending = ConfirmationBillingRequest('s', ['batch-plus:x:1']);
      final store = SecureConfirmationBillingStore(scope: 'a');
      expect((await store.resolve(closed, current)).modelTitle, isNull);
      expect(await const FlutterSecureStorage().readAll(), isEmpty);
      expect((await store.resolve(pending, current)).modelTitle, 'Qwen');
      expect((await store.resolve(closed, old)).modelTitle, 'Qwen');
      final legacy = SecureConfirmationBillingStore(
        scope: 'b',
        legacyRead: (_) async => old,
      );
      expect((await legacy.resolve(closed, current)).modelTitle, 'Doubao');
    },
  );
  test(
    'old snapshot is persisted for all aliases; current model never rewrites history',
    () async {
      var reads = 0;
      final store = SecureConfirmationBillingStore(
        scope: 'prod|a',
        legacyRead: (_) async {
          reads++;
          return old;
        },
      );
      expect((await store.resolve(request, current)).modelTitle, 'Doubao');
      expect((await store.resolve(request, current)).availableBalance, 100);
      expect(reads, 1);
      expect((await const FlutterSecureStorage().readAll()).length, 2);
      expect(
        (await store.resolve(
          ConfirmationBillingRequest('s', ['stable']),
          current,
        )).modelTitle,
        'Doubao',
      );
    },
  );
  test(
    'no old snapshot captures current once and isolates account and session',
    () async {
      final store = SecureConfirmationBillingStore(scope: 'a');
      expect((await store.resolve(request, current)).modelTitle, 'Qwen');
      expect((await store.resolve(request, old)).modelTitle, 'Qwen');
      expect(
        (await SecureConfirmationBillingStore(
          scope: 'b',
        ).resolve(request, old)).modelTitle,
        'Doubao',
      );
      expect(
        (await store.resolve(
          ConfirmationBillingRequest('other', request.aliases),
          old,
        )).modelTitle,
        'Doubao',
      );
    },
  );
  test(
    'new corruption and read failure cannot fall back to current or old',
    () async {
      final disk = ControlledStorage();
      final store = SecureConfirmationBillingStore(scope: 'a', storage: disk);
      await store.resolve(request, old);
      final keys = (await disk.readAll()).keys;
      await disk.write(key: keys.first, value: 'bad');
      await expectLater(store.resolve(request, current), throwsFormatException);
      disk.failRead = true;
      await expectLater(store.resolve(request, current), throwsStateError);
    },
  );
  test(
    'old source and target failures retry without claiming current snapshot',
    () async {
      final disk = ControlledStorage()..failWrite = true;
      var failSource = true;
      final store = SecureConfirmationBillingStore(
        scope: 'a',
        storage: disk,
        legacyRead: (_) async {
          if (failSource) throw StateError('old');
          return old;
        },
      );
      await expectLater(store.resolve(request, current), throwsStateError);
      failSource = false;
      await expectLater(store.resolve(request, current), throwsStateError);
      expect(await disk.readAll(), isEmpty);
      disk.failWrite = false;
      expect((await store.resolve(request, current)).availableBalance, 100);
    },
  );
  test(
    'owner invalidation during old read rejects before persistence',
    () async {
      var active = true;
      final gate = Completer<ConfirmationBillingSnapshot?>(),
          started = Completer<void>();
      final store = SecureConfirmationBillingStore(
        scope: 'a',
        isCurrent: () => active,
        legacyRead: (_) {
          started.complete();
          return gate.future;
        },
      );
      final rejected = expectLater(
        store.resolve(request, current),
        throwsStateError,
      );
      await started.future;
      active = false;
      gate.complete(old);
      await rejected;
      expect(await const FlutterSecureStorage().readAll(), isEmpty);
    },
  );
  test(
    'overlapping aliases across instances keep first committed snapshot',
    () async {
      final a = SecureConfirmationBillingStore(scope: 'a'),
          b = SecureConfirmationBillingStore(scope: 'a');
      final results = await Future.wait([
        a.resolve(request, old),
        b.resolve(ConfirmationBillingRequest('s', ['stable', 'new']), current),
      ]);
      expect(results.map((s) => s.modelTitle).toSet(), {'Doubao'});
      expect((await const FlutterSecureStorage().readAll()).length, 3);
    },
  );
}
