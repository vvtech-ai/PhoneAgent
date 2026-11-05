import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/trusted_caller/domain/trusted_caller.dart';
import 'package:phone_agent/features/trusted_caller/domain/trusted_incoming_identity.dart';
import 'package:phone_agent/features/trusted_caller/presentation/widgets/trusted_identity_presentation_host.dart';
import 'package:phone_agent/features/trusted_caller/presentation/pages/trusted_identity_credentials_page.dart';

void main() {
  const owner = TrustedCallerOwner('synthetic', 'synthetic-phone', 1);
  TrustedIncomingIdentity event(String id, {bool verified = false}) =>
      TrustedIncomingIdentity(
        owner: owner,
        eventId: id,
        name: '身份$id',
        verification: verified
            ? TrustedIdentityVerification.verified
            : TrustedIdentityVerification.pending,
      );
  testWidgets('a closing old route cannot dismiss a newer incoming event', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    final events = ValueNotifier<TrustedIncomingIdentity?>(event('A'));
    final dismissed = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        builder: (_, child) => ValueListenableBuilder<TrustedIncomingIdentity?>(
          valueListenable: events,
          builder: (_, identity, _) => TrustedIdentityPresentationHost(
            navigatorKey: navigator,
            identity: identity,
            onDismiss: (id) {
              dismissed.add(id);
              if (events.value?.eventId == id) events.value = null;
            },
            child: child!,
          ),
        ),
        home: const Scaffold(body: Text('业务首页')),
      ),
    );
    await tester.pumpAndSettle();
    navigator.currentState!.pop();
    events.value = event('B');
    await tester.pumpAndSettle();
    expect(dismissed, ['A']);
    expect(find.text('身份B'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    events.dispose();
  });
  testWidgets('updates one route and system back dismisses displayed event', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    final events = ValueNotifier<TrustedIncomingIdentity?>(null);
    final dismissed = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        builder: (_, child) => ValueListenableBuilder<TrustedIncomingIdentity?>(
          valueListenable: events,
          builder: (_, identity, _) => TrustedIdentityPresentationHost(
            navigatorKey: navigator,
            identity: identity,
            onDismiss: dismissed.add,
            child: child!,
          ),
        ),
        home: const Scaffold(body: Text('业务首页')),
      ),
    );
    events.value = event('A');
    await tester.pumpAndSettle();
    expect(find.text('身份A'), findsOneWidget);
    events.value = event('A', verified: true);
    await tester.pumpAndSettle();
    expect(find.text('可信身份凭证'), findsOneWidget);
    events.value = event('B');
    await tester.pumpAndSettle();
    expect(find.text('身份B'), findsOneWidget);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(dismissed, ['B']);
    expect(find.text('业务首页'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    events.dispose();
  });
  testWidgets('account or event end removes only owned route under business', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    final events = ValueNotifier<TrustedIncomingIdentity?>(event('A'));
    final dismissed = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        builder: (_, child) => ValueListenableBuilder<TrustedIncomingIdentity?>(
          valueListenable: events,
          builder: (_, identity, _) => TrustedIdentityPresentationHost(
            navigatorKey: navigator,
            identity: identity,
            onDismiss: dismissed.add,
            child: child!,
          ),
        ),
        home: const Scaffold(body: Text('业务首页')),
      ),
    );
    await tester.pumpAndSettle();
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('其他业务页面')),
      ),
    );
    await tester.pumpAndSettle();
    events.value = null;
    await tester.pumpAndSettle();
    expect(find.text('其他业务页面'), findsOneWidget);
    expect(dismissed, isEmpty);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('业务首页'), findsOneWidget);
    expect(find.text('身份A'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    events.dispose();
  });
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform stale credentials close preserves new event and cover',
      (tester) async {
        final navigator = GlobalKey<NavigatorState>();
        final events = ValueNotifier<TrustedIncomingIdentity?>(event('A'));
        final dismissed = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            navigatorKey: navigator,
            builder: (_, child) =>
                ValueListenableBuilder<TrustedIncomingIdentity?>(
                  valueListenable: events,
                  builder: (_, identity, _) => TrustedIdentityPresentationHost(
                    navigatorKey: navigator,
                    identity: identity,
                    onDismiss: dismissed.add,
                    child: child!,
                  ),
                ),
            home: const Scaffold(body: Text('业务首页')),
          ),
        );
        await tester.pumpAndSettle();
        final oldClose = tester
            .widget<TrustedIdentityCredentialsPage>(
              find.byType(TrustedIdentityCredentialsPage),
            )
            .onBack;
        events.value = event('B');
        await tester.pumpAndSettle();
        oldClose();
        await tester.pumpAndSettle();
        expect(find.text('身份B'), findsOneWidget);
        expect(dismissed, isEmpty);
        final currentClose = tester
            .widget<TrustedIdentityCredentialsPage>(
              find.byType(TrustedIdentityCredentialsPage),
            )
            .onBack;
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('覆盖业务')),
          ),
        );
        await tester.pumpAndSettle();
        currentClose();
        await tester.pumpAndSettle();
        expect(find.text('覆盖业务'), findsOneWidget);
        expect(dismissed, isEmpty);
        navigator.currentState!.pop();
        await tester.pumpAndSettle();
        expect(find.text('身份B'), findsOneWidget);
        currentClose();
        currentClose();
        await tester.pumpAndSettle();
        expect(dismissed, ['B']);
        expect(find.text('业务首页'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        oldClose();
        currentClose();
        expect(tester.takeException(), isNull);
        events.dispose();
      },
    );
  }
}
