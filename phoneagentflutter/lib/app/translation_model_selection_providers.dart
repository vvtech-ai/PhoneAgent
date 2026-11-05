import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/translation/domain/translation_directory.dart';
import '../features/translation/domain/translation_model_selection.dart';
import 'translation_access_providers.dart';
import 'translation_directory_providers.dart';
import 'translation_providers.dart';

final selectedTranslationModelProvider = Provider<TranslationDirectoryModel?>((
  ref,
) {
  final directory = ref.watch(translationDirectoryProvider);
  final access = ref.watch(translationAccessProvider);
  final preferences = ref.watch(translationSetupProvider);
  if ((directory.isLoading && !directory.isRefreshing) ||
      directory.hasError ||
      !preferences.ready ||
      access.loading ||
      directory.valueOrNull == null) {
    return null;
  }
  return selectTranslationModel(
    directory.requireValue,
    preferences.value,
    access.countryIso,
    forced: access.forced,
  );
});
