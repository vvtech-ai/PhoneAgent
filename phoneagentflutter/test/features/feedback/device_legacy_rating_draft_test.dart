import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/features/feedback/data/device_legacy_rating_draft.dart';
import 'package:phone_agent/features/feedback/domain/task_rating.dart';
import '../../support/rating_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('phone_agent/legacy_rating_draft');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final config = AppConfig.parse(
    environment: 'prod',
    apiBaseUrl: 'https://chaken.ai/aiassistant-api/',
  );
  DeviceLegacyRatingDraft source({String account = 'phone-18800000000'}) =>
      DeviceLegacyRatingDraft(
        config: config,
        accountId: account,
        platform: TargetPlatform.android,
        web: false,
      );
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'exact requested account/task envelope maps original retry key',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'read');
        expect(call.arguments, {
          'accountId': 'phone-18800000000',
          'taskType': 'SINGLE',
          'taskId': 'synthetic-task',
        });
        return {
          'version': 1,
          ...Map<String, Object?>.from(call.arguments as Map),
          'draft': '{"taskUnderstanding":3,"submissionKey":"stable-old"}',
        };
      });
      final result = await source().read(ratingEligibility());
      expect(result!.draft.taskUnderstanding, 3);
      expect(result.submissionKey, 'stable-old');
    },
  );

  test('nonproduction/web/iOS never invoke channel', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) => throw StateError('must not call'),
    );
    for (final input in [
      DeviceLegacyRatingDraft(
        config: config,
        accountId: 'a',
        web: true,
        platform: TargetPlatform.android,
      ),
      DeviceLegacyRatingDraft(
        config: config,
        accountId: 'a',
        web: false,
        platform: TargetPlatform.iOS,
      ),
      DeviceLegacyRatingDraft(
        config: AppConfig.parse(
          environment: 'dev',
          apiBaseUrl: 'https://chaken.ai/aiassistant-api/',
        ),
        accountId: 'a',
        web: false,
        platform: TargetPlatform.android,
      ),
      DeviceLegacyRatingDraft(
        config: AppConfig.parse(
          environment: 'prod',
          apiBaseUrl: 'https://other.test/aiassistant-api/',
        ),
        accountId: 'a',
        web: false,
        platform: TargetPlatform.android,
      ),
      DeviceLegacyRatingDraft(
        config: AppConfig.parse(
          environment: 'prod',
          apiBaseUrl: 'https://chaken.ai/other/',
        ),
        accountId: 'a',
        web: false,
        platform: TargetPlatform.android,
      ),
    ]) {
      expect(await input.read(ratingEligibility()), isNull);
    }
  });

  test(
    'wrong envelope and platform errors fail without source details',
    () async {
      for (final patch in <Map<String, Object?>>[
        {'version': 2},
        {'accountId': 'other'},
        {'taskType': 'BATCH'},
        {'taskId': 'other'},
        {'draft': 123},
        {'draft': 'private bad JSON'},
      ]) {
        messenger.setMockMethodCallHandler(
          channel,
          (call) async => {
            'version': 1,
            ...Map<String, Object?>.from(call.arguments as Map),
            'draft': '{}',
            ...patch,
          },
        );
        await expectLater(
          source().read(ratingEligibility()),
          throwsFormatException,
        );
      }
      messenger.setMockMethodCallHandler(
        channel,
        (_) => throw PlatformException(code: 'private'),
      );
      await expectLater(
        source().read(ratingEligibility()),
        throwsA(
          isA<FormatException>().having(
            (e) => e.toString(),
            'sanitized',
            'FormatException: Legacy rating draft unavailable',
          ),
        ),
      );
    },
  );

  test(
    'invalid owner/task rejected before channel; absent source allowed',
    () async {
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (_) async {
        calls++;
        return null;
      });
      for (final account in ['', 'guest', 'a/b', 'a\u0000b', 'x' * 257]) {
        await expectLater(
          source(account: account).read(ratingEligibility()),
          throwsFormatException,
        );
      }
      for (final task in ['', ' ', 'a\u0000b', 'x' * 257]) {
        await expectLater(
          source().read(
            TaskRatingEligibility(
              target: ratingTarget,
              eligible: true,
              taskType: 'SINGLE',
              taskId: task,
            ),
          ),
          throwsFormatException,
        );
      }
      expect(calls, 0);
      expect(await source().read(ratingEligibility()), isNull);
      expect(calls, 1);
    },
  );
}
