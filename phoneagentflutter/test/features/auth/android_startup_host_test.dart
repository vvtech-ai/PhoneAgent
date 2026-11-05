import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/android_startup_host.dart';
import 'package:phone_agent/features/auth/domain/auth_session.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';

class _Store implements SessionStore {
  final result = Completer<AuthSession?>();
  @override
  Future<AuthSession?> read() => result.future;
  @override
  Future<void> write(AuthSession session) async {}
  @override
  Future<void> clear() async {}
}

class _Target extends ConsumerWidget {
  const _Target();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = ref.watch(sessionControllerProvider).phase;
    return Text(phase.name, textDirection: TextDirection.ltr);
  }
}

void main() {
  for (final target in TargetPlatform.values) {
    for (final outcome in ['signedOut', 'signedIn', 'restoreFailed']) {
      testWidgets('$target native splash releases on $outcome', (tester) async {
        debugDefaultTargetPlatformOverride = target;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final store = _Store();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [sessionStoreProvider.overrideWithValue(store)],
            child: const AndroidStartupHost(child: _Target()),
          ),
        );
        expect(
          tester.binding.sendFramesToEngine,
          target != TargetPlatform.android,
        );
        await tester.pump(const Duration(seconds: 1));
        expect(
          tester.binding.sendFramesToEngine,
          target != TargetPlatform.android,
        );
        if (outcome == 'restoreFailed') {
          store.result.completeError(StateError('synthetic failure'));
        } else {
          store.result.complete(
            outcome == 'signedIn'
                ? const AuthSession(
                    accountId: 'fake',
                    phone: '13800000000',
                    accessToken: 'fake',
                  )
                : null,
          );
        }
        await tester.pump();
        await tester.pump();
        expect(tester.binding.sendFramesToEngine, isTrue);
        expect(find.text(outcome), findsOneWidget);
        debugDefaultTargetPlatformOverride = null;
      });
    }
  }

  testWidgets('disposing while restoring releases exactly once', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final store = _Store();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionStoreProvider.overrideWithValue(store)],
        child: const AndroidStartupHost(child: _Target()),
      ),
    );
    expect(tester.binding.sendFramesToEngine, isFalse);
    await tester.pumpWidget(const SizedBox());
    expect(tester.binding.sendFramesToEngine, isTrue);
    store.result.complete(null);
    await tester.pump();
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });
}
