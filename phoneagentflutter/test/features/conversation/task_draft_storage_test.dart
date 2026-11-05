import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/storage/app_local_storage.dart';
import 'package:phone_agent/features/conversation/data/drafts/secure_task_draft_repository.dart';
import 'package:phone_agent/features/conversation/data/drafts/task_draft_account_store.dart';
import 'package:phone_agent/features/conversation/domain/drafts/task_draft.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const owner = ['test', 'https://test', 'owner'];
  const other = ['test', 'https://test', 'other'];
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  SecureTaskDraftRepository draft(List<String> account, String task) =>
      SecureTaskDraftRepository([...account, task]);

  test(
    'new instance read follows pending save and delete in the same task',
    () async {
      final first = draft(owner, 'one');
      final saving = first.save(const TaskDraft('未发送'));
      expect((await draft(owner, 'one').read())!.text, '未发送');
      await saving;
      final deleting = first.save(null);
      expect(await draft(owner, 'one').read(), isNull);
      await deleting;
    },
  );

  test('task deletion preserves other tasks and accounts', () async {
    await draft(owner, 'one').save(const TaskDraft('删除'));
    await draft(owner, 'two').save(const TaskDraft('另一任务'));
    await draft(other, 'one').save(const TaskDraft('另一账号'));
    await TaskDraftAccountStore(owner).clearTask('one');
    expect(await draft(owner, 'one').read(), isNull);
    expect((await draft(owner, 'two').read())!.text, '另一任务');
    expect((await draft(other, 'one').read())!.text, '另一账号');
  });

  test(
    'logout clears only its account including previously unindexed drafts',
    () async {
      final legacy = draft(owner, 'legacy');
      await const FlutterSecureStorage().write(
        key: legacy.key,
        value: '{"text":"旧版本草稿","start":0,"end":0}',
      );
      await draft(owner, 'one').save(const TaskDraft('本账号'));
      await draft(other, 'one').save(const TaskDraft('另一账号'));
      await TaskDraftAccountStore(owner).clearAccount();
      expect(await draft(owner, 'one').read(), isNull);
      expect(await legacy.read(), isNull);
      expect((await draft(other, 'one').read())!.text, '另一账号');
      await draft(owner, 'new').save(const TaskDraft('重新登录的新草稿'));
      expect((await draft(owner, 'new').read())!.text, '重新登录的新草稿');
    },
  );

  test('iOS sandbox uses account keys without enumerating keychain', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final values = <String, String>{};
    final methods = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(AppLocalStorage.channel, (call) async {
      methods.add(call.method);
      final args = call.arguments as Map;
      final key = args['key'] as String;
      switch (call.method) {
        case 'read':
          return values[key];
        case 'write':
          values[key] = args['value'] as String;
          return null;
        case 'delete':
          values.remove(key);
          return null;
        default:
          fail('Unexpected storage enumeration: ${call.method}');
      }
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(AppLocalStorage.channel, null),
    );
    await draft(owner, 'one').save(const TaskDraft('保留'));
    expect((await draft(owner, 'one').read())!.text, '保留');
    await TaskDraftAccountStore(owner).clearAccount();
    expect(await draft(owner, 'one').read(), isNull);
    expect(methods, containsAll(['write', 'read', 'delete']));
  });

  test('read on a reopened page waits for delayed iOS deletion', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final values = <String, String>{};
    final deleting = Completer<void>(), release = Completer<void>();
    var blockDelete = false;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(AppLocalStorage.channel, (call) async {
      final args = call.arguments as Map;
      final key = args['key'] as String;
      if (call.method == 'read') return values[key];
      if (call.method == 'write') values[key] = args['value'] as String;
      if (call.method == 'delete') {
        if (blockDelete) {
          deleting.complete();
          await release.future;
        }
        values.remove(key);
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(AppLocalStorage.channel, null),
    );
    final first = draft(owner, 'delayed');
    await first.save(const TaskDraft('旧输入'));
    blockDelete = true;
    final deletion = first.save(null);
    await deleting.future;
    var readFinished = false;
    final reading = draft(owner, 'delayed').read().then((v) {
      readFinished = true;
      return v;
    });
    await Future<void>.delayed(Duration.zero);
    expect(readFinished, isFalse);
    release.complete();
    await deletion;
    expect(await reading, isNull);
  });
}
