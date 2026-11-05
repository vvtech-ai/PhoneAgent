import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/initialization/presentation/controller/initialization_model_switch_controller.dart';

void main() {
  test(
    'delayed model result survives page removal and refreshes actual model',
    () async {
      final gate = Completer<void>();
      var saves = 0;
      var refreshes = 0;
      final c = InitializationModelSwitchController((_) {
        saves++;
        return gate.future;
      }, () => refreshes++);
      final pending = c.select('DOUBAO', 'Seeduplex');
      expect(c.state, isEmpty);
      await c.select('DOUBAO', 'Seeduplex');
      expect(saves, 1);
      gate.complete();
      await pending;
      expect(c.state, contains('Seeduplex'));
      expect(refreshes, 1);
      c.dispose();
    },
  );
  test('old account result cannot refresh or notify new session', () async {
    final gate = Completer<void>();
    var refreshes = 0;
    final c = InitializationModelSwitchController(
      (_) => gate.future,
      () => refreshes++,
    );
    final pending = c.select('DOUBAO', 'Seeduplex');
    c.dispose();
    gate.complete();
    await pending;
    expect(refreshes, 0);
  });
  test(
    'failed model reports failure without pretending to change selection',
    () async {
      var refreshes = 0;
      final c = InitializationModelSwitchController((_) async {
        throw StateError('synthetic');
      }, () => refreshes++);
      await c.select('DOUBAO', 'Seeduplex');
      expect(c.state, contains('切换失败'));
      expect(refreshes, 0);
      c.dispose();
    },
  );
}
