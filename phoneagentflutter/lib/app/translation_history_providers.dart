import 'diagnostics_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/translation_history/data/api_translation_history_repository.dart';
import '../features/translation_history/domain/translation_history.dart';
import '../features/translation_history/presentation/controller/translation_history_controller.dart';
import 'business_providers.dart';
import 'local_translation_recording_providers.dart';
import '../features/translation_history/data/local_recording_history_repository.dart';

final translationHistoryRepositoryProvider =
    Provider.autoDispose<TranslationHistoryRepository>((ref) {
      final remote = ApiTranslationHistoryRepository(
        ref.watch(accountApiProvider),
        diagnostics: ref.watch(diagnosticJournalProvider).record,
      );
      final local = ref.watch(localTranslationRecordingProvider);
      return local == null
          ? remote
          : LocalRecordingHistoryRepository(remote, local);
    });
final translationHistoryControllerProvider = StateNotifierProvider.autoDispose
    .family<TranslationHistoryController, TranslationHistoryState, String>((
      ref,
      callId,
    ) {
      final controller = TranslationHistoryController(
        ref.watch(translationHistoryRepositoryProvider),
        callId,
      );
      controller.load();
      return controller;
    });
