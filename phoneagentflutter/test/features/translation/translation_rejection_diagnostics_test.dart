import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_translation_details.dart';
import 'package:phone_agent/features/translation/data/translation_rejection_diagnostics.dart';

void main() {
  test('nested rejection preserves fixed hints and strips private values', () {
    final events = <DiagnosticEvent>[];
    recordTranslationRejection(
      events.add,
      'overseasCreate',
      400,
      {
        'error': {
          'code': 'VALIDATION_ERROR',
          'message': 'merchantLanguage invalid secret-response +15551234567',
        },
      },
      {
        'merchantPhone': '+15551234567',
        'userId': 'private-owner',
        'capabilities': {},
        'realtimeProvider': 'google-gemini-live-translate',
      },
    );
    final detail = events.single.translation!;
    expect(events.single.statusCode, 400);
    expect(detail.code, 'VALIDATION_ERROR');
    expect(detail.statistics['fieldMerchantLanguage'], 1);
    expect(detail.statistics['requestGemini'], 1);
    expect(detail.statistics['requestCapabilities'], 1);
    final exported = jsonEncode(detail.toJson());
    for (final private in [
      'secret-response',
      '+15551234567',
      'private-owner',
    ]) {
      expect(exported, isNot(contains(private)));
    }
    expect(
      DiagnosticTranslationDetails.fromJson(detail.toJson()).toJson(),
      detail.toJson(),
    );
  });
  test('arbitrary error codes and non-object responses stay fixed', () {
    final events = <DiagnosticEvent>[];
    recordTranslationRejection(events.add, 'overseasCreate', 400, {
      'code': 'token-secret',
      'message': 'userLanguageSuffix',
    }, {});
    expect(events.single.translation!.code, 'SERVER_REJECTED');
    expect(events.single.translation!.statistics['fieldUserLanguage'], 0);
    recordTranslationRejection(
      events.add,
      'overseasCreate',
      502,
      'private gateway response',
      null,
    );
    expect(events.last.translation!.statistics['responseObject'], 0);
    expect(
      () => recordTranslationRejection(
        (_) => throw StateError('sink'),
        'overseasCreate',
        400,
        {},
        {},
      ),
      returnsNormally,
    );
  });
}
