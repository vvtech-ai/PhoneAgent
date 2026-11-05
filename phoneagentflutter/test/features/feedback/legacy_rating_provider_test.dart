import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/app_providers.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/conversation_providers.dart';
import 'package:phone_agent/app/task_rating_providers.dart';
import 'package:phone_agent/core/config/app_config.dart';
import '../../support/local_storage_channel_fake.dart';
import '../../support/rating_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('phone_agent/legacy_rating_draft');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  ProviderContainer container(String environment) => ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(
        AppConfig.parse(
          environment: environment,
          apiBaseUrl: 'https://chaken.ai/aiassistant-api/',
        ),
      ),
      currentAccountIdProvider.overrideWithValue('phone-18800000000'),
      loginEpochProvider.overrideWithValue(1),
    ],
  );
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  setUp(installLocalStorageChannelFake);
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('formal provider only enables Android production migration', () async {
    var calls = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls++;
      return {
        'version': 1,
        ...Map<String, Object?>.from(call.arguments as Map),
        'draft': '{"taskCompletion":5,"submissionKey":"old-key"}',
      };
    });
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      debugDefaultTargetPlatformOverride = platform;
      for (final environment in ['dev', 'prod']) {
        final c = container(environment);
        final draft = await c
            .read(taskRatingDraftStoreProvider)
            .read(ratingEligibility());
        if (platform == TargetPlatform.android && environment == 'prod') {
          expect(draft!.submissionKey, 'old-key');
        } else {
          expect(draft, isNull);
        }
        c.dispose();
      }
    }
    expect(calls, 1);
  });

  test(
    'provider invalidation closes a pending import before persistence',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final c = container('prod');
      final started = Completer<void>(),
          gate = Completer<Map<String, Object?>>();
      messenger.setMockMethodCallHandler(channel, (call) {
        started.complete();
        return gate.future;
      });
      final old = c.read(taskRatingDraftStoreProvider);
      final read = old.read(ratingEligibility());
      final rejected = expectLater(read, throwsStateError);
      await started.future;
      c.invalidate(taskRatingDraftStoreProvider);
      gate.complete({
        'version': 1,
        'accountId': 'phone-18800000000',
        'taskType': 'SINGLE',
        'taskId': 'synthetic-task',
        'draft': '{}',
      });
      await rejected;
      expect(await const FlutterSecureStorage().readAll(), isEmpty);
      await expectLater(old.read(ratingEligibility()), throwsStateError);
      c.dispose();
    },
  );
}
