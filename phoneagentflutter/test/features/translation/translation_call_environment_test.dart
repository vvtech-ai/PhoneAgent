import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/domain/translation_call_environment.dart';
import '../../support/translation_interactive_fixture.dart';

void main() {
  test(
    'unavailable environment rejects subtitle corrections as native does',
    () async {
      final f = InteractiveSessionFixture();
      try {
        await f.controller.start();
        f.live.wire('call_connected');
        void text(String value) => f.live.wire(
          'transcript_delta',
          fields: {
            'segmentId': 'known',
            'sourceLeg': 'merchant',
            'kind': 'output',
            'text': value,
            'replace': true,
          },
        );
        text('已确认字幕');
        f.live.wire(
          'environment',
          fields: {
            'environment': {
              'version': 1,
              'model': {'state': 'unavailable'},
            },
          },
        );
        text('不可用阶段');
        expect(f.controller.snapshot.transcripts.single.translated, '已确认字幕');
        await f.controller.hangup();
        text('结束后不可用');
        expect(f.controller.snapshot.transcripts.single.translated, '已确认字幕');
      } finally {
        await f.close();
      }
    },
  );

  test(
    'native versioned partial patches reject stale invalid and unknown state',
    () {
      const initial = TranslationCallEnvironment();
      for (final version in [null, '1', -1, double.nan, double.infinity]) {
        expect(
          identical(
            initial.apply({
              'version': version,
              'network': {'state': 'available'},
            }),
            initial,
          ),
          isTrue,
        );
      }
      final first = initial.apply({
        'version': 2,
        'network': {'state': ' AVAILABLE '},
        'sip': {'state': 'not-applicable'},
        'model': {'state': 'degraded'},
        'riskMessage': ' 合成风险提示 ',
      });
      expect(first.network, TranslationEnvironmentState.available);
      expect(first.sip, TranslationEnvironmentState.notApplicable);
      expect(first.overall, TranslationEnvironmentState.degraded);
      expect(first.riskMessage, '合成风险提示');
      expect(
        identical(
          first.apply({
            'version': 1,
            'network': {'state': 'unavailable'},
          }),
          first,
        ),
        isTrue,
      );
      final next = first.apply({
        'version': 2,
        'network': {'state': 'invented'},
        'model': {'state': 'available'},
        'riskMessage': '',
      });
      expect(next.network, first.network);
      expect(next.sip, first.sip);
      expect(next.overall, TranslationEnvironmentState.available);
      expect(next.riskMessage, first.riskMessage);
      expect(
        next.apply({
          'version': 3,
          'network': {'state': 'not_applicable'},
          'model': {'state': 'not_applicable'},
        }).overall,
        TranslationEnvironmentState.notApplicable,
      );
      expect(
        const TranslationCallEnvironment(
          network: TranslationEnvironmentState.available,
        ).overall,
        TranslationEnvironmentState.pending,
      );
    },
  );
  test(
    'formal session projects only current call and ignores late terminal environment',
    () async {
      final f = InteractiveSessionFixture();
      try {
        await f.controller.start();
        expect(
          f.controller.snapshot.environment.overall,
          TranslationEnvironmentState.pending,
        );
        void emit(int version, String state, {String id = 'session'}) =>
            f.live.wire(
              'environment',
              id: id,
              fields: {
                'environment': {
                  'version': version,
                  'network': {'state': state},
                },
              },
            );
        emit(1, 'degraded', id: 'other');
        expect(f.controller.snapshot.environment.version, -1);
        emit(1, 'degraded');
        expect(
          f.controller.snapshot.environment.network,
          TranslationEnvironmentState.degraded,
        );
        f.live.wire('call_connected');
        expect(
          f.controller.snapshot.environment.model,
          TranslationEnvironmentState.pending,
        );
        emit(0, 'available');
        expect(
          f.controller.snapshot.environment.network,
          TranslationEnvironmentState.degraded,
        );
        await f.controller.coordinator.stop();
        emit(5, 'available');
        expect(f.controller.snapshot.environment.version, 1);
        expect(
          f.controller.snapshot.environment.network,
          TranslationEnvironmentState.degraded,
        );
      } finally {
        await f.close();
      }
    },
  );
}
