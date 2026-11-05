import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/features/feedback/data/secure_task_rating_draft_store.dart';
import 'package:phone_agent/features/feedback/domain/task_rating.dart';
import 'package:phone_agent/features/feedback/domain/task_rating_draft_store.dart';
import '../../support/rating_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.parse(
    environment: 'dev',
    apiBaseUrl: 'https://example.test/api/',
  );
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'draft and stable key survive reload; account/environment/task isolated',
    () async {
      final e = ratingEligibility(),
          store = SecureTaskRatingDraftStore(config, 'a');
      await store.save(
        e,
        const SavedRatingDraft(completeRating, submissionKey: 'stable'),
      );
      expect(
        (await SecureTaskRatingDraftStore(config, 'a').read(e))!.submissionKey,
        'stable',
      );
      expect(await SecureTaskRatingDraftStore(config, 'b').read(e), isNull);
      expect(
        await SecureTaskRatingDraftStore(
          AppConfig.parse(
            environment: 'prod',
            apiBaseUrl: 'https://example.test/api/',
          ),
          'a',
        ).read(e),
        isNull,
      );
      expect(
        await store.read(
          const TaskRatingEligibility(
            target: ratingTarget,
            eligible: true,
            taskType: 'SINGLE',
            taskId: 'other',
          ),
        ),
        isNull,
      );
      expect(
        (await SecureTaskRatingDraftStore(
          AppConfig.parse(
            environment: 'dev',
            apiBaseUrl: 'https://example.test/api',
          ),
          'a',
        ).read(e))!.draft.taskCompletion,
        5,
      );
    },
  );
  test(
    'queued edits/save/clear preserve order and malformed data reports failure',
    () async {
      final e = ratingEligibility(),
          store = SecureTaskRatingDraftStore(config, 'a');
      final a = store.save(e, const SavedRatingDraft(completeRating));
      final b = store.save(
        e,
        const SavedRatingDraft(completeRating, submissionKey: 'stable'),
      );
      await Future.wait([a, b]);
      expect((await store.read(e))!.submissionKey, 'stable');
      final keys = (await const FlutterSecureStorage().readAll()).keys;
      await const FlutterSecureStorage().write(
        key: keys.single,
        value: 'malformed',
      );
      await expectLater(store.read(e), throwsFormatException);
      await Future.wait([
        store.save(e, const SavedRatingDraft(completeRating)),
        store.clear(e),
      ]);
      expect(await store.read(e), isNull);
    },
  );
}
