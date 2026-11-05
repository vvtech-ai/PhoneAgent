import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/invite_providers.dart';
import 'package:phone_agent/features/invite/presentation/controller/invite_controller.dart';
import 'package:phone_agent/features/invite/presentation/pages/invite_page.dart';
import 'package:phone_agent/features/invite/presentation/pages/invite_activity_route.dart';
import 'invite_fakes.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'copy notices queue and allow immediate v67 records $platform $scale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 680);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final repo = FakeInviteRepository();
          final device = FakeInviteDevice();
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                inviteRepositoryProvider.overrideWithValue(repo),
                inviteDeviceProvider.overrideWithValue(device),
              ],
              child: MaterialApp(
                theme: ThemeData(platform: platform),
                home: const InviteActivityRoute(title: '福利'),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final container = ProviderScope.containerOf(
            tester.element(find.byType(InviteActivityRoute)),
          );
          final controller = container.read(inviteControllerProvider.notifier);
          Future<void> tap(String label) async {
            await tester.scrollUntilVisible(
              find.text(label),
              100,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.ensureVisible(find.text(label));
            await tester.pumpAndSettle();
            await tester.tap(find.text(label));
            await tester.pumpAndSettle();
          }

          await tap('邀请好友');
          expect(find.byType(InvitePage), findsOneWidget);
          await controller.copy(false);
          await tester.pump();
          expect(find.text('已复制'), findsOneWidget);
          await tester.pump(const Duration(milliseconds: 700));
          await controller.copy(true);
          await tester.pump();
          expect(find.text('已复制'), findsOneWidget);
          // The first copy finishes before the second copy starts its lifetime.
          await tester.pump(const Duration(milliseconds: 181));
          await tester.pump(const Duration(milliseconds: 1200));
          expect(find.text('已复制'), findsOneWidget);
          await tester.pump(const Duration(milliseconds: 600));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 181));
          await tester.pump();
          await tester.pumpAndSettle();
          expect(find.text('已复制'), findsOneWidget);
          await tester.pump(const Duration(milliseconds: 1800));
          await tester.pumpAndSettle();
          expect(find.text('已复制'), findsNothing);
          expect(find.byType(SnackBar), findsNothing);
          await tap('复制链接');
          expect(device.copied, sampleCode.url);
          expect(find.text('已复制'), findsOneWidget);
          await tester.tap(find.byTooltip('返回'));
          await tester.pumpAndSettle();
          // The disposed poster notice must not block invitation records.
          await tap('邀请记录');
          expect(find.text('本期邀请记录'), findsOneWidget);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 181));
          await tester.pump(const Duration(seconds: 2));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 181));
          await tester.pump();
          await tester.pump();
          expect(find.text('已复制'), findsNothing);
          // The disposed poster does not display later shared-controller feedback.
          await controller.copy(false);
          await tester.pump();
          expect(find.text('已复制'), findsNothing);
          expect(repo.events, [
            'COPY_CODE',
            'COPY_LINK',
            'COPY_LINK',
            'COPY_CODE',
          ]);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await device.received.close();
        },
      );
    }
  }
  testWidgets('covered poster ignores shared action feedback', (tester) async {
    final device = FakeInviteDevice();
    final controller = InviteController(FakeInviteRepository(), device);
    await controller.refresh();
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [inviteControllerProvider.overrideWith((_) => controller)],
        child: MaterialApp(navigatorKey: navigator, home: const InvitePage()),
      ),
    );
    await tester.pumpAndSettle();
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('合成覆盖页')),
      ),
    );
    await tester.pumpAndSettle();
    await controller.copy(true);
    await tester.pump();
    expect(find.text('已复制'), findsNothing);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('已复制'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await device.received.close();
  });
}
