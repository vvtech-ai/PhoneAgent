import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/tasks/domain/task_pinned_visibility.dart';
import '../features/tasks/data/secure_task_pinned_preferences.dart';
import 'app_providers.dart';
import 'business_providers.dart';
import 'conversation_providers.dart';

final taskPinnedPreferenceProvider =
    Provider.autoDispose<TaskPinnedPreferenceRepository>((ref) {
      ref.watch(loginEpochProvider);
      final config = ref.watch(appConfigProvider);
      return SecureTaskPinnedPreferences([
        config.environment?.name ?? '',
        '${config.apiBaseUri}',
        ref.watch(currentAccountIdProvider),
      ]);
    });
