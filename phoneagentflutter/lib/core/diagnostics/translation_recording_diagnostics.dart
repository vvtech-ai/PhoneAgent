import 'dart:async';
import 'package:flutter/services.dart';
import 'diagnostic_event.dart';
import 'diagnostic_translation_details.dart';

/// Fixed stages and categories only. No exception text, paths or media locators.
class TranslationRecordingDiagnostics {
  const TranslationRecordingDiagnostics(this.sink);
  final DiagnosticSink? sink;

  Future<T> run<T>(
    String stage,
    Future<T> Function() work, {
    bool missingIfNull = false,
  }) async {
    report(stage, DiagnosticResult.started);
    try {
      final result = await work();
      report(
        stage,
        missingIfNull && result == null
            ? DiagnosticResult.received
            : DiagnosticResult.succeeded,
      );
      return result;
    } catch (error) {
      report(stage, DiagnosticResult.failed, error);
      rethrow;
    }
  }

  void report(String stage, DiagnosticResult result, [Object? error]) {
    emitDiagnostic(
      sink,
      DiagnosticEvent(
        operation: DiagnosticOperation.translationCall,
        result: result,
        translation: DiagnosticTranslationDetails(
          stage,
          '',
          error is PlatformException ? error.code : '',
        ),
        failureKind: error == null
            ? null
            : error is FormatException
            ? DiagnosticFailureKind.format
            : error is PlatformException
            ? DiagnosticFailureKind.platform
            : error is TimeoutException
            ? DiagnosticFailureKind.timeout
            : error is StateError
            ? DiagnosticFailureKind.state
            : DiagnosticFailureKind.other,
      ),
    );
  }
}
