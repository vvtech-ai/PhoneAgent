import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/app_update/domain/app_update.dart';
import 'package:phone_agent/features/app_update/domain/startup_update.dart';
import 'package:phone_agent/features/app_update/presentation/widgets/ios_update_dialog.dart';
import '../../support/startup_update_fakes.dart';

void main() {
  late int opens, dismisses, refreshes;
  var fail = false;
  Completer<void>? opening;
  Future<void> show(WidgetTester tester, {bool force = false}) async {
    opens = dismisses = refreshes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (_) => IosUpdateDialog(
                offer: StartupUpdateOffer(
                  startupApp,
                  AppUpdateRelease(
                    hasUpdate: true,
                    packageName: startupApp.packageName,
                    versionName: '2.0',
                    forceUpdate: force,
                    sourceType: 1,
                    iosSourceUrl: 'https://apps.apple.com/app/id6813455647',
                  ),
                ),
                open: (link) async {
                  opens++;
                  expect(link, 'https://apps.apple.com/app/id6813455647');
                  if (fail) throw StateError('synthetic');
                  await opening?.future;
                },
                onLater: () {
                  dismisses++;
                  Navigator.of(context).pop();
                },
                onRefresh: () async {
                  refreshes++;
                },
              ),
            ),
            child: const Text('show'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('show'));
    await tester.pumpAndSettle();
  }

  setUp(() {
    fail = false;
    opening = null;
  });
  Future<void> tapUpdate(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('startup-update-install')));
    await tester.pump();
  }

  Future<void> returnToApp(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
  }

  testWidgets('ordinary update hands off and dismisses without install UI', (
    tester,
  ) async {
    await show(tester);
    await tapUpdate(tester);
    await tester.pumpAndSettle();
    expect(opens, 1);
    expect(dismisses, 1);
    expect(refreshes, 0);
    expect(find.text('发现新版本'), findsNothing);
  });
  testWidgets('open failure retains force dialog and allows retry', (
    tester,
  ) async {
    fail = true;
    await show(tester, force: true);
    expect(find.text('稍后'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('发现重要版本更新'), findsOneWidget);
    await tapUpdate(tester);
    await tester.pumpAndSettle();
    expect(find.text('无法打开更新链接，请重试'), findsOneWidget);
    fail = false;
    await tapUpdate(tester);
    await tester.pumpAndSettle();
    expect(opens, 2);
    expect(dismisses, 0);
    await returnToApp(tester);
    expect(refreshes, 1);
    expect(find.text('发现重要版本更新'), findsOneWidget);
  });
  testWidgets(
    'return before native completion rechecks once; duplicate tap ignored',
    (tester) async {
      opening = Completer<void>();
      await show(tester, force: true);
      await tapUpdate(tester);
      await tapUpdate(tester);
      expect(opens, 1);
      await returnToApp(tester);
      expect(refreshes, 0);
      opening!.complete();
      await tester.pumpAndSettle();
      expect(refreshes, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(refreshes, 1);
    },
  );
  testWidgets('disposed dialog ignores late link response', (tester) async {
    opening = Completer<void>();
    await show(tester, force: true);
    await tapUpdate(tester);
    await tester.pumpWidget(const SizedBox());
    opening!.complete();
    await tester.pumpAndSettle();
    expect(dismisses, 0);
    expect(refreshes, 0);
    expect(tester.takeException(), isNull);
  });
}
