import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/features/translation/domain/translation_backend_session.dart';
import 'package:phone_agent/features/translation/domain/translation_media_port.dart';
import 'package:phone_agent/features/translation/domain/translation_service_catalog.dart';
import 'package:phone_agent/features/translation/domain/translation_session_coordinator.dart';
import '../../support/translation_session_fixture.dart';

void main() {
  for (final scenario in ['languages', 'create', 'media', 'sink']) {
    test(
      '$scenario diagnostic identifies failure without changing cleanup',
      () async {
        final f = SessionFixture();
        final events = <DiagnosticEvent>[];
        if (scenario == 'create') {
          f.backend.createFailure = const TranslationBackendFailure(
            'HTTP',
            status: 403,
          );
        }
        if (scenario == 'media') {
          f.live.fail = true;
          f.ws.fail = true;
        }
        final coordinator = TranslationSessionCoordinator(
          backend: f.backend,
          loadLanguages: () async => scenario == 'languages'
              ? const TranslationServiceCatalog([])
              : f.catalog,
          mediaFactory: (kind) =>
              kind == TranslationMediaTransport.liveKit ? f.live : f.ws,
          onStage: (_, __) {},
          diagnostics: scenario == 'sink'
              ? (_) => throw StateError('diagnostic storage')
              : events.add,
        );
        await coordinator.start(translationRequest);
        if (scenario == 'sink') {
          expect(coordinator.stage, TranslationSessionStage.ringing);
        } else {
          expect(coordinator.stage, TranslationSessionStage.failed);
          final failures = events
              .where((e) => e.result == DiagnosticResult.failed)
              .toList();
          expect(
            failures.last.translation!.stage,
            {
              'languages': 'overseasLanguages',
              'create': 'overseasCreate',
              'media': 'overseasMedia',
            }[scenario],
          );
          if (scenario == 'create') expect(failures.last.statusCode, 403);
          if (scenario == 'media') {
            expect(
              failures.map((e) => e.translation!.stage),
              containsAll(['overseasLiveKit', 'overseasWebsocket']),
            );
            expect(f.events, contains('hangup'));
          }
          final wire = jsonEncode(events.map((e) => e.toJson()).toList());
          expect(wire, isNot(contains('synthetic')));
          expect(wire, isNot(contains('+12025550101')));
          for (final event in events) {
            expect(
              DiagnosticEvent.fromJson(event.toJson()).translation!.stage,
              event.translation!.stage,
            );
          }
        }
        await coordinator.dispose();
      },
    );
  }
}
