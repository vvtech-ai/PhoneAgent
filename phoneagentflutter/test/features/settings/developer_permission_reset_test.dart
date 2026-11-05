import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/dial_permission_providers.dart';
import 'package:phone_agent/app/dial_recent_providers.dart';
import 'package:phone_agent/app/translation_location_providers.dart';
import 'package:phone_agent/app/translation_providers.dart';
import 'package:phone_agent/features/dialer/data/preview_dial_permission_port.dart';
import 'package:phone_agent/features/dialer/data/dial_recent_sources.dart';
import 'package:phone_agent/features/dialer/domain/dial_permission.dart';
import 'package:phone_agent/features/dialer/domain/dial_permission_store.dart';
import 'package:phone_agent/core/design/native_business_dialog.dart';
import 'package:phone_agent/features/dialer/domain/dial_recent_source.dart';
import 'package:phone_agent/features/settings/presentation/widgets/developer_permission_reset.dart';
import 'package:phone_agent/features/translation/data/preview_translation_location.dart';
import 'package:phone_agent/features/translation/domain/translation_location.dart';
import 'package:phone_agent/features/translation/domain/translation_preference_store.dart';
import 'package:phone_agent/features/translation/domain/translation_preferences.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_setup_controller.dart';
import 'package:phone_agent/features/translation/presentation/pages/translation_dialer_route.dart';

void main() {
  testWidgets('covered reset cannot mutate after permission memory loads', (
    tester,
  ) async {
    final store = _DelayedPermissionStore();
    final memory = DialPermissionMemory(store: store);
    final setup = TranslationSetupController()..enable(false);
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dialPermissionMemoryProvider.overrideWithValue(memory),
          translationSetupProvider.overrideWith((_) => setup),
        ],
        child: MaterialApp(
          navigatorKey: navigator,
          home: const Scaffold(body: DeveloperPermissionReset()),
        ),
      ),
    );
    await tester.tap(find.text('重置'));
    await tester.pump();
    navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Text('cover')),
    );
    await tester.pumpAndSettle();
    store.gate.complete((
      locationShown: true,
      locationRequested: true,
      callLogRequested: true,
    ));
    await tester.pumpAndSettle();
    expect(memory.generation, 0);
    expect(memory.locationShown, isTrue);
    expect(memory.callLogRequested, isTrue);
    expect(setup.snapshot.enabled, isFalse);
    expect(find.text('cover'), findsOneWidget);
    expect(find.text('模拟权限已重置'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform covered and disposed reset remains inert', (
      tester,
    ) async {
      final memory = DialPermissionMemory()..locationShown = true;
      final setup = TranslationSetupController()..enable(false);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dialPermissionMemoryProvider.overrideWithValue(memory),
            translationSetupProvider.overrideWith((_) => setup),
          ],
          child: MaterialApp(
            navigatorKey: navigator,
            theme: ThemeData(platform: platform),
            home: const Scaffold(body: DeveloperPermissionReset()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final reset = tester
          .widget<TextButton>(find.byType(TextButton))
          .onPressed!;
      navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const Text('cover')),
      );
      await tester.pumpAndSettle();
      reset();
      await tester.pumpAndSettle();
      expect(memory.generation, 0);
      expect(memory.locationShown, isTrue);
      expect(setup.snapshot.enabled, isFalse);
      expect(find.text('cover'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const MaterialApp(home: Text('replacement')));
      await tester.pumpAndSettle();
      reset();
      await tester.pumpAndSettle();
      expect(memory.generation, 0);
      expect(find.text('replacement'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('replaced setup cannot reset current permission memory', (
    tester,
  ) async {
    final store = _DelayedStore();
    final old = TranslationSetupController(store: store);
    final next = TranslationSetupController()..enable(false);
    final selected = StateProvider<TranslationSetupController>((_) => old);
    final memory = DialPermissionMemory()..locationShown = true;
    final container = ProviderContainer(
      overrides: [
        dialPermissionMemoryProvider.overrideWithValue(memory),
        translationSetupProvider.overrideWith((ref) => ref.watch(selected)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: DeveloperPermissionReset()),
        ),
      ),
    );
    await tester.tap(find.text('重置'));
    await tester.pump();
    container.read(selected.notifier).state = next;
    await tester.pump();
    store.gate.complete(const TranslationPreferences(enabled: false));
    await tester.pumpAndSettle();
    expect(memory.generation, 0);
    expect(memory.locationShown, isTrue);
    expect(next.snapshot.enabled, isFalse);
    expect(find.byType(TranslationDialerRoute), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'formal reset opens translation route, preserves cache and CallLog marker',
    (tester) async {
      final store = _DelayedPermissionStore();
      final memory = DialPermissionMemory(store: store);
      final port = PreviewDialPermissionPort()
        ..grant = DialPermissionGrant.blocked;
      final location = PreviewTranslationLocation()
        ..cached = TrustedTranslationLocation('JP', 1);
      final setup = TranslationSetupController()..enable(false);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dialPermissionMemoryProvider.overrideWithValue(memory),
            dialPermissionPortProvider.overrideWithValue(port),
            translationLocationSourceProvider.overrideWithValue(location),
            translationLocationStoreProvider.overrideWithValue(location),
            translationSetupProvider.overrideWith((_) => setup),
            systemDialRecentSourceProvider.overrideWithValue(
              const UnavailableDialRecentSource(DialRecentAccess.unsupported),
            ),
            appDialRecentSourceProvider.overrideWithValue(
              const UnavailableDialRecentSource(DialRecentAccess.unsupported),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: DeveloperPermissionReset()),
          ),
        ),
      );
      await tester.tap(find.text('重置'));
      await tester.pump();
      expect(memory.generation, 0);
      expect(find.byType(TranslationDialerRoute), findsNothing);
      store.gate.complete((
        locationShown: true,
        locationRequested: true,
        callLogRequested: true,
      ));
      await tester.pumpAndSettle();
      expect(find.byType(TranslationDialerRoute), findsOneWidget);
      expect(find.byType(NativeBusinessDialog), findsOneWidget);
      expect(memory.generation, 1);
      expect(memory.locationShown, isTrue);
      expect(memory.locationRequested, isFalse);
      expect(memory.callLogRequested, isTrue);
      expect(setup.snapshot.enabled, isTrue);
      expect(port.grant, DialPermissionGrant.blocked);
      expect(location.cached!.countryIso, 'JP');
      expect(find.text('模拟权限已重置'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('nativeNoticeSurface')), findsNothing);
      await tester.tap(find.text('暂不开启'));
      await tester.pumpAndSettle();
      expect(setup.snapshot.enabled, isFalse);
      expect(port.trace, ['location:check', 'callLog:check']);
      expect(location.requests, 0);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(DeveloperPermissionReset), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _DelayedStore implements TranslationPreferenceStore {
  final gate = Completer<TranslationPreferences>();
  @override
  Future<TranslationPreferences> read() => gate.future;
  @override
  Future<void> write(TranslationPreferences value) async {}
}

class _DelayedPermissionStore implements DialPermissionStore {
  final gate = Completer<DialPermissionFlags>();
  @override
  Future<DialPermissionFlags> read() => gate.future;
  @override
  Future<void> write(DialPermissionFlags value) async {}
}
