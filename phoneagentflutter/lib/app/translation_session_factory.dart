import '../core/diagnostics/diagnostic_event.dart';
import '../features/translation/domain/translation_backend_session.dart';
import '../features/translation/domain/translation_media_port.dart';
import '../features/translation/domain/translation_service_catalog.dart';
import '../features/translation/domain/translation_call_finished.dart';
import '../features/translation/presentation/controller/translation_session_controller.dart';
import '../features/translation/presentation/controller/translation_finished_recorder.dart';
import '../features/translation/presentation/controller/translation_archive_controller.dart';

/// Composition shared by production entry and isolated previews. Entry remains
/// responsible for permission/location admission and complete media ports.
class TranslationSessionFactory {
  TranslationSessionFactory(
    this.recorder, {
    this.archive,
    this.diagnostics,
    this.onFinished,
    this.onDtmfInput,
  });
  final TranslationFinishedRecorder recorder;
  final DiagnosticSink? diagnostics;
  final TranslationArchiveController? archive;
  final void Function(TranslationCallFinished)? onFinished;
  final void Function()? onDtmfInput;

  TranslationSessionController create({
    required TranslationBackendRepository backend,
    required TranslationMediaFactory mediaFactory,
    required Future<TranslationServiceCatalog> Function() loadLanguages,
    required TranslationCreateRequest request,
    required String targetName,
    required String countryIso,
    TranslationCallContext? context,
    DateTime Function()? now,
    void Function()? onReleased,
  }) {
    if (!recorder.available || request.userId != recorder.accountId) {
      throw StateError('Translation account is unavailable');
    }
    return TranslationSessionController(
      diagnostics: diagnostics,
      backend: backend,
      mediaFactory: mediaFactory,
      loadLanguages: loadLanguages,
      request: request,
      context:
          context ??
          TranslationCallContext.create(
            targetName: targetName,
            countryIso: countryIso,
          ),
      now: now,
      onFinished: (finished) {
        if (!recorder.available || finished.accountId != recorder.accountId) {
          return;
        }
        recorder.accept(finished);
        onFinished?.call(finished);
      },
      onArchive: archive?.observe,
      onReleased: onReleased,
      onDtmfInput: onDtmfInput,
    );
  }
}
