import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/domain/translation_call_view.dart';
import '../../support/translation_interactive_fixture.dart';

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  test(
    'cancel releases preparation even if transport connect stays pending',
    () async {
      final f = InteractiveSessionFixture();
      f.live.connectGate = Completer<void>();
      f.live.releaseConnectOnClose = false;
      final start = f.controller.start();
      await flush();
      await f.controller.coordinator.stop().timeout(const Duration(seconds: 1));
      await start;
      expect(f.trace, isNot(contains('merchant')));
      expect(f.trace, isNot(contains('connect:ws')));
      expect(f.trace.where((e) => e == 'hangup'), hasLength(1));
      expect(f.controller.snapshot.phase, TranslationPhase.ended);
      f.live.connectGate!.complete();
      await f.close();
    },
  );

  test('server termination during preparation never falls back', () async {
    final f = InteractiveSessionFixture();
    f.live.connectGate = Completer<void>();
    final start = f.controller.start();
    await flush();
    f.live.wire('call_ended');
    await f.controller.coordinator.stop();
    await start;
    expect(f.trace, isNot(contains('merchant')));
    expect(f.trace, isNot(contains('connect:ws')));
    await f.close();
  });

  for (final done in [false, true]) {
    test(
      'preparation stream ${done ? 'done' : 'error'} falls back once',
      () async {
        final f = InteractiveSessionFixture();
        f.live.connectGate = Completer<void>();
        final start = f.controller.start();
        await flush();
        expect(f.trace, contains('connect:live'));
        if (done) {
          await f.live.stream.close();
        } else {
          f.live.stream.addError(StateError('synthetic transport failure'));
        }
        await start;
        expect(
          f.trace.indexOf('close:live'),
          lessThan(f.trace.indexOf('connect:ws')),
        );
        expect(f.trace.where((e) => e == 'merchant'), hasLength(1));
        expect(f.controller.snapshot.phase, TranslationPhase.ringing);
        await f.close();
      },
    );
  }

  test(
    'stream failure after dialing terminates without fallback or replay',
    () async {
      final f = InteractiveSessionFixture();
      await f.controller.start();
      f.live.stream.addError(StateError('synthetic transport failure'));
      await f.controller.coordinator.stop();
      expect(f.trace, isNot(contains('connect:ws')));
      expect(f.trace.where((e) => e == 'merchant'), hasLength(1));
      expect(f.trace.where((e) => e == 'hangup'), hasLength(1));
      expect(f.controller.snapshot.phase, TranslationPhase.failed);
      await f.close();
    },
  );
}
