import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/about_providers.dart';
import 'package:phone_agent/app/app_update_providers.dart';
import 'package:phone_agent/app/log_report_providers.dart';
import 'package:phone_agent/core/design/native_setting_controls.dart';
import 'package:phone_agent/features/app_logs/domain/app_log_report.dart';
import 'package:phone_agent/features/app_update/domain/app_update.dart';
import 'package:phone_agent/features/app_update/presentation/controller/app_update_controller.dart';
import 'package:phone_agent/features/settings/presentation/pages/about_page.dart';
import 'package:phone_agent/features/settings/presentation/pages/about_route.dart';
import '../../support/startup_update_fakes.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'about account follows update with consistent rows at scale=$scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var taps = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: AboutPage(
                version: 'V1.2.3',
                onDocument: (_) {},
                showUpdate: true,
                onUpdate: () => taps++,
              ),
            ),
          ),
        );
        final list = tester.widget<ListView>(find.byType(ListView));
        final children =
            (list.childrenDelegate as SliverChildListDelegate).children;
        expect(children.last.key, const Key('about-account'));
        expect(children[children.length - 2].key, const Key('about-update'));
        final row = find.byKey(const Key('about-update'));
        await tester.scrollUntilVisible(row, 200);
        await tester.ensureVisible(row);
        final card = tester.widget<NativeSettingCard>(row);
        expect(card.subtitle, isEmpty);
        expect(card.value, isEmpty);
        expect(card.homeLayout, isFalse);
        expect(
          find.descendant(of: row, matching: find.textContaining('1.2.3')),
          findsNothing,
        );
        await tester.tap(row);
        expect(taps, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'iOS about exposes update without automatically requesting',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aboutMetadataSourceProvider.overrideWithValue(StartupSourceFake()),
            logReportRepositoryProvider.overrideWithValue(_Logs()),
            appUpdateControllerProvider.overrideWith(
              (_) => AppUpdateController(
                StartupSourceFake(),
                StartupRepositoryFake(),
              ),
            ),
          ],
          child: const MaterialApp(home: AboutRoute()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('V1.0'), findsOneWidget);
      expect(find.byKey(const Key('about-update')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({TargetPlatform.iOS}),
  );

  testWidgets(
    'Android busy deduplicates and failure retries with latest notice',
    (tester) async {
      final repo = StartupRepositoryFake()
        ..pending = Completer<AppUpdateRelease>();
      await tester.pumpWidget(_host(repo));
      await tester.pumpAndSettle();
      expect(repo.checks, 0);
      final row = find.byKey(const Key('about-update'));
      await tester.scrollUntilVisible(row, 150);
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pump();
      expect(repo.checks, 1);
      expect(tester.widget<NativeSettingCard>(row).value, '检测中');
      expect(tester.widget<NativeSettingCard>(row).onTap, isNull);
      await tester.tap(row);
      expect(repo.checks, 1);
      repo.pending!.completeError(StateError('synthetic'));
      await tester.pumpAndSettle();
      expect(find.text('版本检查失败，请稍后重试'), findsOneWidget);
      expect(tester.widget<NativeSettingCard>(row).value, isEmpty);
      // The shared FIFO notice finishes before the next check's feedback.
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      repo.pending = null;
      repo.release = startupRelease(update: false);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(repo.checks, 2);
      expect(find.text('当前已是最新版本'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  for (final dispose in [false, true]) {
    testWidgets(
      'late update notice suppressed dispose=$dispose',
      (tester) async {
        final repo = StartupRepositoryFake()
          ..pending = Completer<AppUpdateRelease>();
        final nav = GlobalKey<NavigatorState>();
        await tester.pumpWidget(_host(repo, navigatorKey: nav));
        await tester.pumpAndSettle();
        final page = tester.widget<AboutPage>(find.byType(AboutPage));
        page.onUpdate!();
        await tester.pump();
        if (dispose) {
          await tester.pumpWidget(const MaterialApp(home: Text('replacement')));
        } else {
          nav.currentState!.push(
            MaterialPageRoute<void>(builder: (_) => const Text('cover')),
          );
        }
        await tester.pumpAndSettle();
        page.onUpdate!();
        expect(repo.checks, 1);
        repo.pending!.complete(startupRelease(update: false));
        await tester.pumpAndSettle();
        expect(find.text('当前已是最新版本'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
      variant: TargetPlatformVariant({TargetPlatform.android}),
    );
  }
}

Widget _host(
  StartupRepositoryFake repo, {
  GlobalKey<NavigatorState>? navigatorKey,
}) => ProviderScope(
  overrides: [
    startupUpdateSupportedProvider.overrideWithValue(false),
    aboutMetadataSourceProvider.overrideWithValue(StartupSourceFake()),
    installedAppSourceProvider.overrideWithValue(StartupSourceFake()),
    appUpdateRepositoryProvider.overrideWithValue(repo),
    logReportRepositoryProvider.overrideWithValue(_Logs()),
  ],
  child: MaterialApp(navigatorKey: navigatorKey, home: const AboutRoute()),
);

class _Logs implements AppLogRepository {
  @override
  Future<AppLogBundle> prepare() async => AppLogBundle(
    watermark: 0,
    count: 0,
    bytes: Uint8List(0),
    fileName: 'synthetic.zip',
  );
  @override
  Future<void> upload(AppLogBundle bundle) async {}
  @override
  Future<void> acknowledge(AppLogBundle bundle) async {}
}
