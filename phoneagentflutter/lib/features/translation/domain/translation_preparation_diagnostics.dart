import 'dart:async';
import '../../../core/diagnostics/diagnostic_event.dart';
import '../../../core/diagnostics/diagnostic_translation_details.dart';
import 'translation_backend_session.dart';
import 'translation_service_catalog.dart';

void recordTranslationPreparation(
  DiagnosticSink? sink,
  String stage,
  DiagnosticResult result, {
  Object? error,
  int status = 0,
}) {
  final code = error is TranslationBackendFailure
      ? error.code
      : error == TranslationCatalogFailure.unavailable
      ? 'CATALOG_UNAVAILABLE'
      : error == TranslationCatalogFailure.network
      ? 'CATALOG_NETWORK'
      : error == TranslationCatalogFailure.rejected
      ? 'CATALOG_REJECTED'
      : error == TranslationCatalogFailure.invalidResponse
      ? 'CATALOG_INVALID_RESPONSE'
      : error is TimeoutException
      ? 'TIMEOUT'
      : error is StateError && stage == 'overseasLanguages'
      ? 'LANGUAGE_UNSUPPORTED'
      : error == null
      ? ''
      : 'UNKNOWN';
  emitDiagnostic(
    sink,
    DiagnosticEvent(
      operation: DiagnosticOperation.translationCall,
      result: result,
      failureKind: error == null
          ? null
          : error is TimeoutException
          ? DiagnosticFailureKind.timeout
          : error is FormatException
          ? DiagnosticFailureKind.format
          : error is StateError
          ? DiagnosticFailureKind.state
          : DiagnosticFailureKind.other,
      statusCode: error is TranslationBackendFailure
          ? error.status ?? status
          : status,
      translation: DiagnosticTranslationDetails(stage, code),
    ),
  );
}
