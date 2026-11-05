import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/design/page_route_visibility.dart';
import 'package:phone_agent/features/auth/domain/auth_session.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/account_cancellation/presentation/cancellation_providers.dart';
import 'package:phone_agent/features/settings/presentation/pages/account_route.dart';
import 'cancellation_scenario.dart';

class CancellationRouteStore implements SessionStore {
  AuthSession? saved = const AuthSession(
    accountId: 'synthetic-a',
    phone: '13800000000',
    accessToken: 'synthetic-not-a-credential',
  );
  int clears = 0;
  bool fail = false;
  Completer<void>? gate;
  @override
  Future<AuthSession?> read() async => saved;
  @override
  Future<void> write(AuthSession value) async => saved = value;
  @override
  Future<void> clear() async {
    clears++;
    await gate?.future;
    if (fail) throw StateError('synthetic storage failure');
    saved = null;
  }
}

Future<ProviderContainer> hostCancellationRoute(
  WidgetTester tester,
  CancellationRouteStore store,
  CancellationScenario gateway, {
  List<Override> overrides = const [],
}) async {
  final container = ProviderContainer(
    overrides: [
      sessionStoreProvider.overrideWithValue(store),
      cancellationGatewayProvider.overrideWithValue(gateway),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  final visibility = PageRouteVisibilityObserver();
  addTearDown(visibility.dispose);
  await container.read(sessionControllerProvider.notifier).restore();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: PageRouteVisibilityScope(
        observer: visibility,
        child: MaterialApp(
          navigatorObservers: [visibility],
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(builder: (_) => const AccountRoute()),
                ),
                child: const Text('root-account'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('root-account'));
  await tester.pumpAndSettle();
  return container;
}

Future<void> openCancellationEntry(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('account-delete')));
  await tester.pumpAndSettle();
}

Future<void> confirmCancellationEntry(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('account-confirmation-input')),
    '确认注销',
  );
  await tester.pump();
  await tester.ensureVisible(
    find.byKey(const Key('account-entry-confirmation-submit')),
  );
  await tester.tap(find.byKey(const Key('account-entry-confirmation-submit')));
}
