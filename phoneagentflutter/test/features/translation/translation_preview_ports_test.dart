import 'dart:async';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/data/preview_translation_session.dart';
import 'package:phone_agent/features/translation/domain/translation_call_view.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_session_controller.dart';

void main() {
  for (final scenario in ['normal', 'fallback']) {
    test(
      'synthetic $scenario closes with shared runtime under fake clock',
      () => fakeAsync((clock) {
        final port = PreviewTranslationSession(scenario: scenario);
        final controller = TranslationSessionController(
          backend: port,
          mediaFactory: port.media,
          loadLanguages: port.languages,
          request: PreviewTranslationSession.request,
        );
        unawaited(controller.start());
        clock.flushMicrotasks();
        port.ready();
        clock.flushMicrotasks();
        expect(
          controller.snapshot.phase,
          TranslationPhase.ringing,
          reason: port.trace.toString(),
        );
        port.ended();
        clock.flushMicrotasks();
        clock.elapse(Duration.zero);
        expect(
          controller.snapshot.phase,
          TranslationPhase.ended,
          reason: '${port.trace} stopping=${controller.snapshot.stopping}',
        );
        controller.dispose();
        clock.flushMicrotasks();
        expect(clock.pendingTimers, isEmpty);
      }),
    );
  }
}
