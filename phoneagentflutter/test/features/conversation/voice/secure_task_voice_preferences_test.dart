import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/storage/app_local_storage.dart';
import 'package:phone_agent/features/conversation/data/voice/secure_task_voice_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('phone_agent/task_voice_preferences');
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AppLocalStorage.channel, null);
  });
  test(
    'read-only legacy task preferences migrate once and cannot overwrite newer Flutter preference',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      var reads = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            reads++;
            expect(call.method, 'readLegacy');
            return {'speechEnabled': false, 'guideCompleted': true};
          });
      const repo = SecureTaskVoicePreferences();
      final old = await repo.read();
      expect(old.speechEnabled, isFalse);
      expect(old.guideCompleted, isTrue);
      await repo.speech(true);
      expect((await repo.read()).speechEnabled, isTrue);
      expect(reads, 1);
    },
  );
  test(
    'iOS device defaults and persistence use shared contract without Android migration',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      FlutterSecureStorage.setMockInitialValues({});
      final values = <String, String>{};
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (_) async => fail('iOS called Android migration'),
          );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(AppLocalStorage.channel, (call) async {
            final args = call.arguments as Map;
            expect(args['kind'], 'preference');
            final key = args['key'] as String;
            if (call.method == 'read') return values[key];
            if (call.method == 'write') {
              values[key] = args['value'] as String;
              return null;
            }
            fail('Unexpected storage operation');
          });
      const repo = SecureTaskVoicePreferences();
      expect((await repo.read()).speechEnabled, isTrue);
      expect((await repo.read()).guideCompleted, isFalse);
      await repo.speech(false);
      await repo.completeGuide();
      expect((await repo.read()).speechEnabled, isFalse);
      expect((await repo.read()).guideCompleted, isTrue);
    },
  );
}
