import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/translation/data/api_translation_directory.dart';
import '../features/translation/domain/translation_directory.dart';
import 'business_providers.dart';

final translationDirectoryProvider = FutureProvider<TranslationDirectory>((
  ref,
) {
  ref.watch(loginEpochProvider);
  return ApiTranslationDirectory(ref.watch(accountApiProvider)).load();
});
