import 'dart:async';
import 'package:flutter/services.dart';
import 'package:phone_agent/app/app_update_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/about_providers.dart';
import 'package:phone_agent/app/log_report_providers.dart';
import 'package:phone_agent/features/app_update/domain/app_update.dart';
import 'package:phone_agent/features/app_logs/domain/app_log_report.dart';
import 'package:phone_agent/features/auth/domain/legal_document_port.dart';
import 'package:phone_agent/features/auth/presentation/controller/legal_document_providers.dart';
import 'package:phone_agent/features/settings/presentation/pages/about_route.dart';
import 'package:phone_agent/features/settings/presentation/pages/about_page.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform about reads metadata and exposes all actions at 2x',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final source = _Source(), documents = _Documents(), logs = _Logs();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              aboutMetadataSourceProvider.overrideWithValue(source),
              legalDocumentPortProvider.overrideWithValue(documents),
              logReportRepositoryProvider.overrideWithValue(logs),
            ],
            child: MaterialApp(
              theme: ThemeData(platform: platform),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: const AboutRoute(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('V1.2.3'), findsOneWidget);
        expect(source.reads, 1);
        expect(logs.uploads, 0);
        expect(documents.opened, isEmpty);
        Future<void> tap(String key) async {
          final target = find.byKey(ValueKey(key));
          await tester.scrollUntilVisible(
            target,
            150,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.ensureVisible(target);
          await tester.pumpAndSettle();
          await tester.tap(target);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }

        for (final document in LegalDocument.values) {
          await tap('about-${document.name}');
        }
        expect(documents.opened, LegalDocument.values);
        expect(find.byKey(const Key('about-logs')), findsNothing);
        expect(logs.uploads, 0);
        expect(logs.cleanups, 0);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );
  }

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform covered and disposed about actions stay inert', (
      tester,
    ) async {
      final source = _Source()..fail = true;
      final documents = _Documents(), logs = _Logs();
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aboutMetadataSourceProvider.overrideWithValue(source),
            legalDocumentPortProvider.overrideWithValue(documents),
            logReportRepositoryProvider.overrideWithValue(logs),
          ],
          child: MaterialApp(
            navigatorKey: navigator,
            theme: ThemeData(platform: platform),
            home: const AboutRoute(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final page = tester.widget<AboutPage>(find.byType(AboutPage));
      final reads = source.reads;
      navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const Text('cover')),
      );
      await tester.pumpAndSettle();
      page.onDocument(LegalDocument.userAgreement);
      await tester.pumpAndSettle();
      expect(documents.opened, isEmpty);
      expect(source.reads, reads);
      expect(logs.uploads, 0);
      expect(find.text('cover'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const MaterialApp(home: Text('replacement')));
      await tester.pumpAndSettle();
      page.onDocument(LegalDocument.userAgreement);
      await tester.pumpAndSettle();
      expect(documents.opened, isEmpty);
      expect(source.reads, reads);
      expect(logs.uploads, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'version failure stays blank and document failure never sends logs',
    (tester) async {
      final source = _Source()..fail = true;
      final documents = _Documents()..fail = true;
      final logs = _Logs();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aboutMetadataSourceProvider.overrideWithValue(source),
            legalDocumentPortProvider.overrideWithValue(documents),
            logReportRepositoryProvider.overrideWithValue(logs),
          ],
          child: const MaterialApp(home: AboutRoute()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('about-version')), findsNothing);
      expect(find.text('版本读取失败'), findsNothing);
      expect(find.text('重试读取版本'), findsNothing);
      expect(tester.widget<AboutPage>(find.byType(AboutPage)).version, '');
      expect(source.reads, 1);
      await tester.ensureVisible(find.byKey(const Key('about-userAgreement')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('about-userAgreement')));
      await tester.pumpAndSettle();
      expect(find.text('暂时无法打开协议，请重试'), findsOneWidget);
      expect(logs.uploads, 0);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
  testWidgets(
    'default About source reads current platform channel dynamically',
    (tester) async {
      const channel = MethodChannel('com.vvtech.phone_agent/app_info');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var reads = 0;
      var installedVersion = '2.7.4';
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'read');
        reads++;
        return {
          'packageName': 'com.example.current',
          'versionName': installedVersion,
          'versionCode': 42,
        };
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            startupUpdateSupportedProvider.overrideWithValue(false),
            logReportRepositoryProvider.overrideWithValue(_Logs()),
          ],
          child: const MaterialApp(home: AboutRoute()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('V2.7.4'), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AboutRoute)),
      );
      installedVersion = ' 3.1.0-dev ';
      container.invalidate(aboutVersionProvider);
      await tester.pumpAndSettle();
      expect(find.text('V3.1.0-dev'), findsOneWidget);
      expect(find.text('V2.7.4'), findsNothing);
      expect(reads, 2);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  for (final outcome in ['empty', 'whitespace', 'failure']) {
    testWidgets(
      'loading and $outcome version remain silent',
      (tester) async {
        final pending = Completer<InstalledApp>();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              startupUpdateSupportedProvider.overrideWithValue(false),
              aboutVersionProvider.overrideWith((_) => pending.future),
              logReportRepositoryProvider.overrideWithValue(_Logs()),
            ],
            child: const MaterialApp(home: AboutRoute()),
          ),
        );
        await tester.pump();
        void expectBlank() {
          expect(tester.widget<AboutPage>(find.byType(AboutPage)).version, '');
          expect(find.byKey(const Key('about-version')), findsNothing);
          expect(find.text('正在读取版本…'), findsNothing);
          expect(find.text('版本读取失败'), findsNothing);
          expect(find.text('重试读取版本'), findsNothing);
        }

        expectBlank();
        if (outcome == 'failure') {
          pending.completeError(
            PlatformException(code: 'APP_INFO_UNAVAILABLE'),
          );
        } else {
          pending.complete(
            InstalledApp(
              'com.example.current',
              outcome == 'empty' ? '' : '  ',
              1,
            ),
          );
        }
        await tester.pumpAndSettle();
        expectBlank();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
      variant: TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.iOS,
      }),
    );
  }
}

class _Source implements InstalledAppSource {
  int reads = 0;
  bool fail = false;
  @override
  Future<InstalledApp> read() async {
    reads++;
    if (fail) throw StateError('synthetic');
    return const InstalledApp('com.example.synthetic', '1.2.3', 3);
  }
}

class _Documents implements LegalDocumentPort {
  final opened = <LegalDocument>[];
  bool fail = false;
  @override
  Future<void> open(LegalDocument document) async {
    opened.add(document);
    if (fail) throw StateError('synthetic');
  }
}

class _Logs implements AppLogRepository {
  int uploads = 0, cleanups = 0;
  @override
  Future<AppLogBundle> prepare() async => AppLogBundle(
    watermark: 0,
    count: 0,
    bytes: Uint8List(0),
    fileName: 'synthetic.zip',
  );
  @override
  Future<void> upload(AppLogBundle bundle) async {
    uploads++;
  }

  @override
  Future<void> acknowledge(AppLogBundle bundle) async {
    cleanups++;
  }
}
