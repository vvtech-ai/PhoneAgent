import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/storage/app_local_storage.dart';
import 'package:phone_agent/features/conversation/data/drafts/secure_task_draft_repository.dart';
import 'package:phone_agent/features/conversation/data/voice/secure_task_voice_preferences.dart';
import 'package:phone_agent/features/conversation/domain/drafts/task_draft.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final files = <String, String>{};
  final calls = <MethodCall>[];
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    files.clear();
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AppLocalStorage.channel, (call) async {
          calls.add(call);
          final args = Map<String, dynamic>.from(call.arguments as Map);
          final key = '${args['kind']}:${args['key']}';
          switch (call.method) {
            case 'read':
              return files[key];
            case 'write':
              files[key] = args['value'] as String;
              return null;
            case 'delete':
              files.remove(key);
              return null;
          }
          throw StateError('Unexpected call');
        });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AppLocalStorage.channel, null);
  });
  test(
    'Android delegates to original plugin and never calls iOS channel',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      const store = AppLocalStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      );
      expect(store.aOptions.toMap()['encryptedSharedPreferences'], 'true');
      await store.write(key: 'sample', value: 'value');
      expect(await const FlutterSecureStorage().read(key: 'sample'), 'value');
      expect(await store.read(key: 'sample'), 'value');
      expect(await store.containsKey(key: 'sample'), isTrue);
      await store.delete(key: 'sample');
      expect(await store.read(key: 'sample'), isNull);
      expect(calls, isEmpty);
    },
  );
  test(
    'iOS draft is encrypted storage and speech preference is sandbox preference',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final drafts = SecureTaskDraftRepository(['test', 'synthetic']);
      await drafts.save(const TaskDraft('synthetic draft', start: 2, end: 2));
      expect((await drafts.read())?.text, 'synthetic draft');
      expect(calls.first.arguments['kind'], 'encrypted');
      expect(await const FlutterSecureStorage().readAll(), isEmpty);
      final preferences = const SecureTaskVoicePreferences();
      // Exercise the actual business class rather than only the adapter.
      await preferences.speech(false);
      expect(calls.last.arguments['kind'], 'preference');
      expect(await const FlutterSecureStorage().readAll(), isEmpty);
    },
  );
  test(
    'iOS channel failure is propagated, never falls back to Keychain',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(AppLocalStorage.channel, (_) async {
            throw PlatformException(code: 'local_storage_unavailable');
          });
      await expectLater(
        const AppLocalStorage().read(key: 'sample'),
        throwsA(isA<PlatformException>()),
      );
      expect(await const FlutterSecureStorage().readAll(), isEmpty);
      expect(() => const AppLocalStorage().deleteAll(), throwsUnsupportedError);
    },
  );
}
