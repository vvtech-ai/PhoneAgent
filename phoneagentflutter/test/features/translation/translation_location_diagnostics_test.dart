import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_translation_location_details.dart';

void main() {
  test(
    'location diagnostic survives export round trip without arbitrary data',
    () {
      final event = DiagnosticEvent(
        operation: DiagnosticOperation.translationLocationPreflight,
        result: DiagnosticResult.failed,
        translationLocation: DiagnosticTranslationLocationDetails({
          'stage': 'domesticPreflight',
          'reason': 'loading',
          'source': 'real',
          'realStatus': 'loading',
          'realCountry': '',
          'effectiveCountry': 'CN',
          'snapshotSimulation': '',
          'currentSimulation': 'CN',
          'simulationMatches': 'false',
          'token': 'synthetic-secret',
          'selectedCountry': 'arbitrary text',
          'selectedStatus': 'arbitrary text',
        }),
      );
      final wire = jsonEncode(event.toJson());
      final restored = DiagnosticEvent.fromJson(
        jsonDecode(wire) as Map<String, dynamic>,
      );
      expect(
        restored.translationLocation!.values,
        event.translationLocation!.values,
      );
      expect(restored.translationLocation!.values['reason'], 'loading');
      expect(wire, isNot(contains('synthetic-secret')));
      expect(wire, isNot(contains('arbitrary text')));
    },
  );
  test('legacy events remain readable and sink failure is isolated', () {
    final event = DiagnosticEvent(
      operation: DiagnosticOperation.translationCall,
      result: DiagnosticResult.started,
    );
    expect(
      DiagnosticEvent.fromJson(event.toJson()).translationLocation,
      isNull,
    );
    expect(
      () => emitDiagnostic((_) => throw StateError('storage'), event),
      returnsNormally,
    );
  });
}
