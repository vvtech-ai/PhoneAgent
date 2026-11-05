import '../../../core/diagnostics/diagnostic_event.dart';
import '../../../core/diagnostics/diagnostic_translation_details.dart';

/// Server text is inspected only for fixed categories; never exported verbatim.
void recordTranslationRejection(
  DiagnosticSink? sink,
  String stage,
  int status,
  Object? response,
  Object? request,
) {
  final outer = response is Map ? response : const {};
  final nested = outer['error'] is Map ? outer['error'] as Map : const {};
  final rawCode = outer['code'] ?? nested['code'] ?? outer['error'];
  const codes = {
    'UNKNOWN_FIELD',
    'INVALID_REQUEST',
    'VALIDATION_ERROR',
    'UNSUPPORTED_PROVIDER',
    'INSUFFICIENT_BALANCE',
  };
  final code = rawCode is String && codes.contains(rawCode)
      ? rawCode
      : 'SERVER_REJECTED';
  final hints = [
    outer['message'],
    outer['detail'],
    nested['message'],
    outer['field'],
    nested['field'],
  ].whereType<String>().join(' ');
  final body = request is Map ? request : const {};
  bool mentions(String name) =>
      RegExp(r'\b' + name + r'\b', caseSensitive: false).hasMatch(hints);
  emitDiagnostic(
    sink,
    DiagnosticEvent(
      operation: DiagnosticOperation.translationCall,
      result: DiagnosticResult.failed,
      statusCode: status,
      translation: DiagnosticTranslationDetails(stage, code, '', {
        'responseObject': response is Map ? 1 : 0,
        'nestedError': outer['error'] is Map ? 1 : 0,
        'requestCapabilities': body.containsKey('capabilities') ? 1 : 0,
        'requestGemini':
            body['realtimeProvider'] == 'google-gemini-live-translate' ? 1 : 0,
        'fieldMerchantPhone': mentions('merchantPhone') ? 1 : 0,
        'fieldUserLanguage': mentions('userLanguage') ? 1 : 0,
        'fieldMerchantLanguage': mentions('merchantLanguage') ? 1 : 0,
        'fieldRealtimeProvider': mentions('realtimeProvider') ? 1 : 0,
        'fieldCapabilities': mentions('capabilities') ? 1 : 0,
        'fieldOriginalAudio':
            mentions('originalAudioEnabled') ||
                mentions('originalAudioPercent') ||
                mentions('originalAudioVolumePercent')
            ? 1
            : 0,
      }),
    ),
  );
}
