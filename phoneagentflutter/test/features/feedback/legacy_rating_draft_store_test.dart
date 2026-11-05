import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/features/feedback/data/secure_task_rating_draft_store.dart';
import 'package:phone_agent/features/feedback/domain/task_rating.dart';
import 'package:phone_agent/features/feedback/domain/task_rating_draft_store.dart';
import 'package:phone_agent/features/feedback/presentation/controller/task_rating_controller.dart';
import '../../support/rating_fakes.dart';

class DraftStorage extends FlutterSecureStorage {
  final values = <String, String>{};
  bool failRead = false, failWrite = false;
  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (failRead) throw StateError('synthetic read');
    return values[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (failWrite) throw StateError('synthetic write');
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}

void main() {
  final config = AppConfig.parse(
    environment: 'prod',
    apiBaseUrl: 'https://chaken.ai/aiassistant-api/',
  );
  final e = ratingEligibility();
  const old = SavedRatingDraft(completeRating, submissionKey: 'old-stable-key');
  late DraftStorage storage;
  var reads = 0;
  SecureTaskRatingDraftStore store({
    String account = 'a',
    Future<SavedRatingDraft?> Function(TaskRatingEligibility)? legacy,
  }) => SecureTaskRatingDraftStore(
    config,
    account,
    storage: storage,
    legacyRead:
        legacy ??
        (_) async {
          reads++;
          return old;
        },
  );
  setUp(() {
    storage = DraftStorage();
    reads = 0;
  });

  test(
    'import persists before return and fresh instance never rereads old',
    () async {
      expect((await store().read(e))!.submissionKey, old.submissionKey);
      expect(storage.values, hasLength(1));
      expect((await store().read(e))!.draft.taskCompletion, 5);
      expect(reads, 1);
    },
  );

  test(
    'new draft, corrupt/unknown schema and cleared state never fall back',
    () async {
      final first = store();
      await first.save(
        e,
        const SavedRatingDraft(TaskRatingDraft(suggestion: 'new')),
      );
      expect((await store().read(e))!.draft.suggestion, 'new');
      for (final raw in [
        'broken',
        '{"schema":2}',
        '{"schema":1,"skipClone":false,"suggestion":23,"key":""}',
        '{"schema":1,"understanding":8,"skipClone":false,"suggestion":"","key":""}',
      ]) {
        storage.values[storage.values.keys.single] = raw;
        await expectLater(store().read(e), throwsFormatException);
        expect(storage.values.values.single, raw);
      }
      storage.values[storage.values.keys.single] =
          '{"schema":1,"cleared":true}';
      expect(await store().read(e), isNull);
      expect(reads, 0);
    },
  );

  test(
    'clear before first import and after import survives recreation',
    () async {
      await store().clear(e);
      expect(await store().read(e), isNull);
      expect(reads, 0);
      final b = store(account: 'b');
      await b.read(e);
      await b.clear(e);
      expect(await store(account: 'b').read(e), isNull);
      expect(reads, 1);
    },
  );

  test(
    'no old draft recorded once; read/write failure remains retryable',
    () async {
      final absent = store(
        legacy: (_) async {
          reads++;
          return null;
        },
      );
      expect(await absent.read(e), isNull);
      expect(await store().read(e), isNull);
      expect(reads, 1);
      storage.values.clear();
      storage.failRead = true;
      await expectLater(store().read(e), throwsStateError);
      expect(reads, 1);
      storage.failRead = false;
      storage.failWrite = true;
      await expectLater(store().read(e), throwsStateError);
      expect(storage.values, isEmpty);
      storage.failWrite = false;
      expect((await store().read(e))!.submissionKey, old.submissionKey);
      expect(reads, 3);
    },
  );

  test(
    'failed legacy parse/read does not mark or overwrite anything',
    () async {
      await expectLater(
        store(
          legacy: (_) async => throw const FormatException('unavailable'),
        ).read(e),
        throwsFormatException,
      );
      expect(storage.values, isEmpty);
      expect(await store().read(e), isNotNull);
    },
  );

  test(
    'cross-instance late import cannot overwrite later save or clear',
    () async {
      for (final clear in [false, true]) {
        storage.values.clear();
        final started = Completer<void>(),
            gate = Completer<SavedRatingDraft?>();
        final importing = store(
          legacy: (_) {
            started.complete();
            return gate.future;
          },
        ).read(e);
        await started.future;
        final later = clear
            ? store().clear(e)
            : store().save(
                e,
                const SavedRatingDraft(TaskRatingDraft(suggestion: 'new')),
              );
        gate.complete(old);
        await importing;
        await later;
        final result = await store().read(e);
        if (clear) {
          expect(result, isNull);
        } else {
          expect(result!.draft.suggestion, 'new');
        }
      }
    },
  );

  test(
    'close prevents late import and queued writes; new account unaffected',
    () async {
      final started = Completer<void>(), gate = Completer<SavedRatingDraft?>();
      final first = store(
        legacy: (_) {
          started.complete();
          return gate.future;
        },
      );
      final importing = first.read(e);
      final readExpectation = expectLater(importing, throwsStateError);
      await started.future;
      final saving = first.save(e, old);
      final saveExpectation = expectLater(saving, throwsStateError);
      first.close();
      gate.complete(old);
      await Future.wait([readExpectation, saveExpectation]);
      expect(storage.values, isEmpty);
      await store(account: 'b').read(e);
      expect(storage.values, hasLength(1));
    },
  );

  test(
    'task/account isolation, not receipt anchor, selects legacy draft',
    () async {
      final targets = <String>[];
      final first = store(
        legacy: (task) async {
          targets.add(task.taskId);
          return old;
        },
      );
      await first.read(e);
      await first.read(
        const TaskRatingEligibility(
          target: ratingTarget,
          eligible: true,
          taskType: 'BATCH',
          taskId: 'other-task',
        ),
      );
      await store(account: 'b').read(e);
      expect(targets, ['synthetic-task', 'other-task']);
      expect(storage.values, hasLength(3));
    },
  );

  test(
    'formal controller reuses imported key, server submission clears tombstone',
    () async {
      final repo = FakeRatingRepository()..fail = true;
      final first = store();
      final controller = TaskRatingController(
        target: ratingTarget,
        repository: repo,
        drafts: first,
        clientVersion: 'test',
        newKey: () => 'must-not-replace',
      );
      await controller.load();
      controller.open();
      await controller.submit();
      await controller.submit();
      expect(repo.keys, [old.submissionKey, old.submissionKey]);
      repo.fail = false;
      await controller.submit();
      expect(await store().read(e), isNull);
      expect(jsonDecode(storage.values.values.single)['cleared'], true);
      controller.dispose();
    },
  );

  test('already submitted server state never imports old draft', () async {
    final repo = FakeRatingRepository()
      ..result = ratingEligibility(
        submission: const TaskRatingSubmission(
          version: 1,
          draft: completeRating,
        ),
      );
    final controller = TaskRatingController(
      target: ratingTarget,
      repository: repo,
      drafts: store(),
      clientVersion: 'test',
    );
    await controller.load();
    expect(controller.state.readOnly, true);
    expect(reads, 0);
    expect(await store().read(e), isNull);
    expect(reads, 0);
    controller.dispose();
  });

  test(
    'corrupt secure draft blocks formal controller until valid retry',
    () async {
      final first = store();
      await first.save(e, old);
      final key = storage.values.keys.single;
      final original = storage.values[key]!;
      storage.values[key] = 'synthetic-corrupt';
      final repo = FakeRatingRepository()..fail = true;
      final controller = TaskRatingController(
        target: ratingTarget,
        repository: repo,
        drafts: first,
        clientVersion: 'test',
      );
      addTearDown(controller.dispose);
      await controller.load();
      controller.open();
      controller.suggestion('must not replace');
      await controller.submit();
      expect(controller.state.draftReadFailed, isTrue);
      expect(storage.values[key], 'synthetic-corrupt');
      expect(repo.keys, isEmpty);
      expect(reads, 0);
      storage.values[key] = original;
      await controller.retryDraft();
      expect(controller.state.canSubmit, isTrue);
      await controller.submit();
      expect(repo.keys, [old.submissionKey]);
      expect(reads, 0);
    },
  );
}
