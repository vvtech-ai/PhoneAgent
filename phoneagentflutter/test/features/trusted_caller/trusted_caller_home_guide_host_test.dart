import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/app_providers.dart';
import 'package:phone_agent/app/trusted_caller_account_providers.dart';
import 'package:phone_agent/app/trusted_caller_home_guide_providers.dart';
import 'package:phone_agent/app/trusted_caller_providers.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/features/trusted_caller/domain/trusted_caller.dart';
import 'package:phone_agent/features/trusted_caller/domain/trusted_caller_home_guide.dart';
import 'package:phone_agent/features/trusted_caller/presentation/widgets/trusted_caller_home_guide_host.dart';
import 'package:phone_agent/features/trusted_caller/presentation/widgets/trusted_caller_home_guide.dart';

const _owner = TrustedCallerOwner('synthetic', 'synthetic', 1);
final _active = StateProvider<bool>((_) => true);
final _ownerState = StateProvider<TrustedCallerOwner?>((_) => _owner);

class _Store implements TrustedCallerHomeGuideStore {
  bool seen = false, disabled = false;
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
    seen = true;
    this.disabled |= disabled;
  }
}

class _Sdk implements TrustedCallerPort, TrustedCallerEntryPort {
  int opens = 0, reads = 0;
  @override
  bool get needsIntroduction => false;
  @override
  Future<bool> prepare(TrustedCallerOwner owner) async => true;
  @override
  Future<void> openSettings(TrustedCallerOwner owner) async {
    opens++;
  }

  @override
  Future<void> releaseSurface(TrustedCallerOwner owner) async {}
  @override
  Future<TrustedCallerReport> readStatus(TrustedCallerOwner owner) async {
    reads++;
    return TrustedCallerReport(
      owner: owner,
      status: TrustedCallerStatus.readyToConfigure,
    );
  }
}

Future<ProviderContainer> _pump(
  WidgetTester tester,
  _Store store,
  _Sdk sdk,
) async {
  late ProviderContainer container;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig.parse(
            environment: 'dev',
            apiBaseUrl: 'https://synthetic.invalid',
          ),
        ),
        trustedCallerOwnerProvider.overrideWith(
          (ref) => ref.watch(_ownerState),
        ),
        trustedCallerAccountReadyProvider.overrideWithValue((_) async => true),
        trustedCallerHomeGuideStoreProvider.overrideWithValue(store),
        trustedCallerPortProvider.overrideWithValue(sdk),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context);
              return TrustedCallerHomeGuideHost(
                active: ref.watch(_active),
                child: SizedBox.expand(
                  child: Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => Scaffold(
                            appBar: AppBar(),
                            body: const Text('other page'),
                          ),
                        ),
                      ),
                      child: const Text('open other page'),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return container;
}

void main() {
  testWidgets(
    'small screen and large text keep guide actions reachable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final store = _Store(), sdk = _Sdk();
      await _pump(tester, store, sdk);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(find.text('可信通信被叫'), findsOneWidget);
      final scroll = find.descendant(
        of: find.byType(TrustedCallerHomeGuide),
        matching: find.byType(SingleChildScrollView),
      );
      await tester.drag(scroll, const Offset(0, -400));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('trusted-home-disable')));
      await tester.pump();
      expect(store.disabled, true);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );

  testWidgets(
    'background cancels delay and foreground can schedule again',
    (tester) async {
      final store = _Store(), sdk = _Sdk();
      await _pump(tester, store, sdk);
      await tester.pump(const Duration(milliseconds: 100));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(store.seen, false);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(find.text('可信通信被叫'), findsOneWidget);
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );

  testWidgets(
    'back and backdrop show reminder; account change closes overlay',
    (tester) async {
      final store = _Store(), sdk = _Sdk();
      final container = await _pump(tester, store, sdk);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('你可以稍后在设置中开启可信通信被叫。'), findsOneWidget);
      container.read(_ownerState.notifier).state = const TrustedCallerOwner(
        'other',
        'other',
        2,
      );
      await tester.pump();
      expect(find.text('你可以稍后在设置中开启可信通信被叫。'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      final freshStore = _Store();
      await _pump(tester, freshStore, sdk);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tester.tapAt(const Offset(10, 10));
      await tester.pump();
      expect(find.text('你可以稍后在设置中开启可信通信被叫。'), findsOneWidget);
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );

  testWidgets(
    'delayed guide closes to reminder and is persisted once',
    (tester) async {
      final store = _Store(), sdk = _Sdk();
      await _pump(tester, store, sdk);
      await tester.pump(const Duration(milliseconds: 299));
      expect(find.text('可信通信被叫'), findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(find.text('可信通信被叫'), findsOneWidget);
      expect(store.seen, true);
      expect(sdk.opens, 0);
      await tester.tap(find.byKey(const Key('trusted-home-close')));
      await tester.pump();
      expect(find.text('你可以稍后在设置中开启可信通信被叫。'), findsOneWidget);
      await tester.tap(find.byKey(const Key('trusted-home-reminder-confirm')));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('可信通信被叫'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await _pump(tester, store, sdk);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('可信通信被叫'), findsNothing);
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );

  testWidgets(
    'disable persists and authorize uses shared SDK entry without refresh',
    (tester) async {
      final store = _Store(), sdk = _Sdk();
      await _pump(tester, store, sdk);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tester.tap(find.byKey(const Key('trusted-home-disable')));
      await tester.pump();
      expect(store.disabled, true);
      expect(find.text('你可以稍后在设置中开启可信通信被叫。'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      final nextStore = _Store();
      await _pump(tester, nextStore, sdk);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tester.tap(find.byKey(const Key('trusted-home-authorize')));
      await tester.tap(find.byKey(const Key('trusted-home-authorize')));
      await tester.pump();
      await tester.pump();
      expect(sdk.opens, 1);
      expect(sdk.reads, 0);
      expect(find.text('可信通信被叫'), findsNothing);
      expect(find.text('可信来电已开启'), findsNothing);
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );

  testWidgets(
    'tab departure and logout cancel pending display',
    (tester) async {
      final store = _Store(), sdk = _Sdk();
      final container = await _pump(tester, store, sdk);
      await tester.pump(const Duration(milliseconds: 100));
      container.read(_active.notifier).state = false;
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(store.seen, false);
      container.read(_active.notifier).state = true;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      container.read(_ownerState.notifier).state = null;
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('可信通信被叫'), findsNothing);
      expect(store.seen, false);
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );

  testWidgets(
    'covered route delays prompt until home returns',
    (tester) async {
      final store = _Store(), sdk = _Sdk();
      await _pump(tester, store, sdk);
      await tester.tap(find.text('open other page'));
      await tester.pumpAndSettle();
      expect(store.seen, false);
      expect(find.text('可信通信被叫'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(find.text('可信通信被叫'), findsOneWidget);
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );

  testWidgets(
    'iOS never loads home guide or opens SDK from home',
    (tester) async {
      final store = _Store(), sdk = _Sdk();
      await _pump(tester, store, sdk);
      await tester.pump(const Duration(seconds: 1));
      expect(store.reads, 0);
      expect(store.seen, false);
      expect(sdk.opens, 0);
      expect(find.text('可信通信被叫'), findsNothing);
    },
    variant: TargetPlatformVariant({TargetPlatform.iOS}),
  );
}
