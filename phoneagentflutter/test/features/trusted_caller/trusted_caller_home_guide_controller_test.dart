import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/trusted_caller/domain/trusted_caller.dart';
import 'package:phone_agent/features/trusted_caller/domain/trusted_caller_home_guide.dart';
import 'package:phone_agent/features/trusted_caller/presentation/controller/trusted_caller_home_guide_controller.dart';

class _Store implements TrustedCallerHomeGuideStore {
  bool seen = false, disabled = false, fail = false;
  int reads = 0;
  @override
  Future<bool> eligible(TrustedCallerOwner owner) async {
    reads++;
    return !seen && !disabled;
  }

  @override
  Future<void> record(
    TrustedCallerOwner owner, {
    required bool disabled,
  }) async {
    if (fail) throw StateError('synthetic failure');
    seen = true;
    this.disabled |= disabled;
  }
}

void main() {
  const owner = TrustedCallerOwner('synthetic', 'synthetic', 1);
  test(
    'only confirmed account loads; seen survives controller recreation',
    () async {
      final store = _Store();
      var confirmed = false;
      TrustedCallerHomeGuideController create() =>
          TrustedCallerHomeGuideController(
            owner: owner,
            store: store,
            ensureAccount: (_) async => confirmed,
          );
      final first = create();
      await first.load();
      expect(first.state.eligible, false);
      expect(store.reads, 0);
      confirmed = true;
      await first.load();
      expect(first.state.eligible, true);
      expect(await first.record(), true);
      expect(store.seen, true);
      expect(store.disabled, false);
      first.dispose();
      final next = create();
      await next.load();
      expect(next.state.eligible, false);
      expect(await next.record(disabled: true), true);
      expect(store.disabled, true);
      next.dispose();
    },
  );
  test('late account confirmation cannot read for disposed owner', () async {
    final ready = Completer<bool>();
    final store = _Store();
    final controller = TrustedCallerHomeGuideController(
      owner: owner,
      store: store,
      ensureAccount: (_) => ready.future,
    );
    final load = controller.load();
    controller.dispose();
    ready.complete(true);
    await load;
    expect(store.reads, 0);
  });
  test(
    'storage failure is not successful disable and can be retried',
    () async {
      final store = _Store()..fail = true;
      final controller = TrustedCallerHomeGuideController(
        owner: owner,
        store: store,
        ensureAccount: (_) async => true,
      );
      expect(await controller.record(disabled: true), false);
      expect(store.disabled, false);
      expect(controller.state.error, isNotEmpty);
      store.fail = false;
      expect(await controller.record(disabled: true), true);
      expect(store.disabled, true);
      controller.dispose();
    },
  );
}
