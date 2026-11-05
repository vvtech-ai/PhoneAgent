import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/settings_providers.dart';
import 'package:phone_agent/features/dialer/domain/system_dialer.dart';
import 'package:phone_agent/features/dialer/presentation/controller/dialer_controller.dart';

class _NeverDial implements SystemDialer {
  @override
  Future<SystemDialResult> open(String number) =>
      throw StateError('unlock must never dial');
}

void main() {
  test(
    'real unlock clears input and only changes in-process visibility',
    () async {
      final scope = ProviderContainer();
      addTearDown(scope.dispose);
      final c = DialerController(
        _NeverDial(),
        onUnlockDeveloper: () =>
            scope.read(developerModeProvider.notifier).state = true,
      );
      addTearDown(c.dispose);
      expect(scope.read(developerModeProvider), isFalse);
      for (final key in '20142014*#'.split('')) {
        c.digit(key);
      }
      await c.dial();
      expect(scope.read(developerModeProvider), isTrue);
      expect(c.state.input, isEmpty);
      expect(c.state.message, '已进入开发者模式');
      final restart = ProviderContainer();
      addTearDown(restart.dispose);
      expect(restart.read(developerModeProvider), isFalse);
    },
  );
  test('MOCK cannot unlock real state even if callback supplied', () async {
    var unlocks = 0;
    final c = DialerController(
      _NeverDial(),
      preview: true,
      onUnlockDeveloper: () => unlocks++,
    );
    addTearDown(c.dispose);
    for (final key in '20142014*#'.split('')) {
      c.digit(key);
    }
    await c.dial();
    expect(unlocks, 0);
    expect(c.state.message, contains('MOCK'));
  });
}
