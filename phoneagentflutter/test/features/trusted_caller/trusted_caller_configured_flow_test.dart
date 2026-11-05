import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/trusted_caller_providers.dart';
import 'package:phone_agent/features/trusted_caller/domain/trusted_caller.dart';
import 'package:phone_agent/features/trusted_caller/presentation/pages/trusted_caller_settings_entry.dart';
import 'package:phone_agent/features/trusted_caller/presentation/pages/trusted_caller_introduction_page.dart';

class FlowPort
    implements
        TrustedCallerPort,
        TrustedCallerGuidePort,
        TrustedCallerEntryPort {
  bool intro = true,
      failPrepare = false,
      failOpen = false,
      failExit = false,
      failRead = false;
  int opens = 0, guides = 0, reads = 0, prepares = 0, releases = 0;
  Completer<bool>? preparing;
  final exited = Completer<void>();
  @override
  bool get needsIntroduction => intro;
  @override
  Future<bool> prepare(TrustedCallerOwner owner) async {
    prepares++;
    if (failPrepare) throw StateError('synthetic prepare failure');
    return preparing == null ? true : preparing!.future;
  }

  @override
  Future<TrustedCallerReport> readStatus(TrustedCallerOwner owner) async {
    reads++;
    if (failRead) throw StateError('synthetic authorization query failure');
    return TrustedCallerReport(
      owner: owner,
      status: TrustedCallerStatus.notAuthorized,
    );
  }

  @override
  Future<void> markIntroductionSeen(TrustedCallerOwner owner) async {
    guides++;
    intro = false;
  }

  @override
  Future<void> openSettings(TrustedCallerOwner owner) async {
    opens++;
    if (failOpen) throw StateError('synthetic open failure');
    await exited.future;
    if (failExit) throw StateError('synthetic exit failure');
  }

  @override
  Future<void> releaseSurface(TrustedCallerOwner owner) async {
    releases++;
  }
}

final ownerState = StateProvider<TrustedCallerOwner?>(
  (_) => const TrustedCallerOwner('synthetic', 'synthetic-phone', 1),
);

Future<ProviderContainer> enter(WidgetTester tester, FlowPort port) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        trustedCallerOwnerProvider.overrideWith((ref) => ref.watch(ownerState)),
        trustedCallerPortProvider.overrideWithValue(port),
      ],
      child: MaterialApp(
        home: TrustedCallerSettingsEntry(
          builder: (context, open) => Scaffold(
            body: Column(
              children: [
                const Text('原设置页'),
                TextButton(onPressed: open, child: const Text('可信入口')),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(TrustedCallerSettingsEntry)),
  );
  expect(port.prepares, 0, reason: 'Building settings must not initialize SDK');
  await tester.tap(find.text('可信入口'));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  const both = TargetPlatformVariant({
    TargetPlatform.iOS,
    TargetPlatform.android,
  });
  testWidgets(
    'preparation stays on settings without authorization read; repeat click ignored',
    (tester) async {
      final port = FlowPort()
        ..intro = false
        ..preparing = Completer<bool>();
      await enter(tester, port);
      expect(find.text('原设置页'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('正在读取状态'), findsNothing);
      await tester.tap(find.text('可信入口'));
      await tester.pump();
      expect(port.prepares, 1);
      expect(port.reads, 0);
      port.preparing!.complete(true);
      await tester.pumpAndSettle();
      expect(port.opens, 1);
      expect(
        port.reads,
        0,
        reason: 'Authorization is not an opening prerequisite',
      );
      port.exited.complete();
      await tester.pumpAndSettle();
      expect(port.reads, defaultTargetPlatform == TargetPlatform.iOS ? 1 : 0);
      expect(find.text('原设置页'), findsOneWidget);
      expect(port.releases, 1);
    },
    variant: both,
  );

  for (final fails in [false, true]) {
    testWidgets(
      'SDK exit never removes settings or covering route failure=$fails',
      (tester) async {
        final port = FlowPort()
          ..intro = false
          ..failExit = fails;
        await enter(tester, port);
        final navigator = Navigator.of(
          tester.element(find.byType(TrustedCallerSettingsEntry)),
        );
        navigator.push<void>(
          MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('覆盖业务页')),
          ),
        );
        await tester.pumpAndSettle();
        port.exited.complete();
        await tester.pumpAndSettle();
        expect(find.text('覆盖业务页'), findsOneWidget);
        navigator.pop();
        await tester.pumpAndSettle();
        expect(find.text('原设置页'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      variant: both,
    );
  }

  for (final cancel in [false, true]) {
    testWidgets(
      'iOS first guide full screen and returns to original settings cancel=$cancel',
      (tester) async {
        final port = FlowPort();
        await enter(tester, port);
        final finder = find.byType(TrustedCallerIntroductionPage);
        expect(finder, findsOneWidget);
        expect(
          (ModalRoute.of(tester.element(finder)) as MaterialPageRoute)
              .fullscreenDialog,
          true,
        );
        expect(port.guides, 1);
        expect(port.reads, 0);
        expect(port.opens, 0);
        if (cancel) {
          tester.widget<TrustedCallerIntroductionPage>(finder).onExit();
        } else {
          await tester.tap(find.text('开始'));
        }
        await tester.pumpAndSettle();
        expect(port.opens, cancel ? 0 : 1);
        if (!cancel) {
          expect(
            finder,
            findsOneWidget,
            reason: 'Guide remains until SDK exits',
          );
          tester.widget<TrustedCallerIntroductionPage>(finder).onStart();
          await tester.pump();
          expect(port.opens, 1);
          port.exited.complete();
          await tester.pumpAndSettle();
        }
        expect(find.text('原设置页'), findsOneWidget);
        expect(finder, findsNothing);
        // Guide was recorded before presentation, including cancel, matching iOS.
        await tester.tap(find.text('可信入口'));
        await tester.pumpAndSettle();
        expect(finder, findsNothing);
        expect(port.guides, 1);
        if (cancel) {
          port.exited.complete();
          await tester.pumpAndSettle();
        }
      },
      variant: const TargetPlatformVariant({TargetPlatform.iOS}),
    );
  }

  testWidgets(
    'Android first guide remains SDK owned without Flutter introduction',
    (tester) async {
      final port = FlowPort();
      await enter(tester, port);
      expect(port.opens, 1);
      expect(port.guides, 0);
      expect(port.reads, 0);
      expect(find.byType(TrustedCallerIntroductionPage), findsNothing);
      port.exited.complete();
      await tester.pumpAndSettle();
      expect(find.text('原设置页'), findsOneWidget);
    },
    variant: const TargetPlatformVariant({TargetPlatform.android}),
  );

  testWidgets(
    'authorization refresh failure does not become an SDK open failure',
    (tester) async {
      final port = FlowPort()
        ..intro = false
        ..failRead = true;
      await enter(tester, port);
      expect(port.opens, 1);
      expect(port.reads, 0);
      port.exited.complete();
      await tester.pumpAndSettle();
      expect(port.reads, defaultTargetPlatform == TargetPlatform.iOS ? 1 : 0);
      expect(find.text('原设置页'), findsOneWidget);
      expect(find.byKey(const ValueKey('nativeNoticeSurface')), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: both,
  );

  for (final stage in ['prepare', 'open']) {
    testWidgets('$stage failure shows notice on settings and click retries', (
      tester,
    ) async {
      final port = FlowPort()
        ..intro = false
        ..failPrepare = stage == 'prepare'
        ..failOpen = stage == 'open';
      await enter(tester, port);
      expect(find.text('原设置页'), findsOneWidget);
      expect(find.byKey(const ValueKey('nativeNoticeSurface')), findsOneWidget);
      port.failPrepare = false;
      port.failOpen = false;
      await tester.tap(find.text('可信入口'));
      await tester.pumpAndSettle();
      expect(port.prepares, 2);
      expect(port.opens, stage == 'open' ? 2 : 1);
      port.exited.complete();
      await tester.pumpAndSettle();
      expect(find.text('原设置页'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, variant: both);
  }

  for (final change in ['account', 'cover', 'dispose']) {
    testWidgets('late preparation does not open after $change', (tester) async {
      final port = FlowPort()..preparing = Completer<bool>();
      final container = await enter(tester, port);
      NavigatorState? navigator;
      if (change == 'account') {
        container.read(ownerState.notifier).state = const TrustedCallerOwner(
          'other',
          'other-phone',
          2,
        );
      } else if (change == 'cover') {
        navigator = Navigator.of(
          tester.element(find.byType(TrustedCallerSettingsEntry)),
        );
        navigator.push<void>(
          MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('覆盖业务页')),
          ),
        );
      } else {
        await tester.pumpWidget(const SizedBox());
      }
      await tester.pumpAndSettle();
      port.preparing!.complete(true);
      await tester.pumpAndSettle();
      expect(port.opens, 0);
      expect(port.guides, 0);
      expect(find.byType(TrustedCallerIntroductionPage), findsNothing);
      if (navigator != null) expect(find.text('覆盖业务页'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, variant: both);
  }
}
