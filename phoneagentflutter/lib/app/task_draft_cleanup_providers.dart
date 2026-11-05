import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/presentation/controller/auth_providers.dart';
import '../features/conversation/data/drafts/task_draft_account_store.dart';
import 'app_providers.dart';
import 'task_draft_cleanup.dart';

/// Capture the owner while signed in; credentials are revoked during release.
final taskDraftAccountStoreProvider = Provider.autoDispose<TaskDraftCleanup?>((
  ref,
) {
  final accountId = ref.watch(
    sessionControllerProvider.select((state) => state.session?.accountId),
  );
  if (accountId == null) return null;
  final config = ref.watch(appConfigProvider);
  return TaskDraftCleanup(
    TaskDraftAccountStore([
      config.environment?.name ?? '',
      '${config.apiBaseUri}',
      accountId,
    ]),
    onFailure: () => debugPrint('task_draft_cleanup_failed'),
  );
});
