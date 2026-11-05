import 'support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/app_update_providers.dart';
import 'package:phone_agent/app/diagnostics_providers.dart';
import 'package:phone_agent/app/log_report_providers.dart';
import 'package:phone_agent/app/phone_agent_app.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_journal.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/app_logs/data/zip_log_repository.dart';
import 'package:phone_agent/features/auth/domain/auth_session.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import '../tool/previews/auth_scenario.dart';
import '../tool/previews/migration_workbench.dart';
import '../tool/previews/shell_log_report_preview.dart';
import '../tool/previews/workbench_catalog.dart';

void main() {
  for (final width in [320.0, 430.0]) {
    testWidgets('settings feedback replaces standalone log action $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MigrationWorkbench(
          scenes: [workbenchScenes.singleWhere((s) => s.id == 'app')],
        ),
      );
      Future<void> tap(String key) async {
        await tester.pumpUntilUiSettled();
        final target = find.byKey(ValueKey(key));
        await tester.scrollUntilVisible(
          target,
          150,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.ensureVisible(target);
        await tester.pumpUntilUiSettled();
        await tester.tap(target);
        await tester.pumpUntilUiSettled();
        expect(tester.takeException(), isNull);
      }

      await tester.tap(find.byKey(const ValueKey('scene-app')));
      await tester.pumpUntilUiSettled();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PhoneAgentApp)),
      );
      await tap('tab-3');
      await tap('settings-about');
      expect(find.byKey(const Key('about-logs')), findsNothing);
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpUntilUiSettled();
      await tap('settings-feedback');
      expect(find.text('问题描述'), findsOneWidget);
      await tap('feedback-submit');
      expect(find.text('请填写问题描述'), findsOneWidget);
      final port = container.read(shellLogReportProvider);
      expect(port.uploads, 0);
      expect(port.cleanups, 0);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpUntilUiSettled();
    });
  }

  test('normal provider keeps ZIP and requires signed-in account', () async {
    const appInfo = MethodChannel('com.vvtech.phone_agent/app_info');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(appInfo, (call) async {
      expect(call.method, anyOf('read', 'readEnvironment'));
      if (call.method == 'readEnvironment') {
        return {
          'appVersionName': '1.0.52',
          'appVersionCode': 45,
          'osName': 'Android',
          'osVersion': '14',
          'apiLevel': 34,
          'deviceBrand': 'google',
          'deviceManufacturer': 'Google',
          'deviceModel': 'Pixel 8',
          'deviceHardwareModel': 'shiba',
        };
      }
      return {
        'packageName': 'com.vvtech.aiassistant.test',
        'versionName': '1.0.52',
        'versionCode': 45,
      };
    });
    addTearDown(() => messenger.setMockMethodCallHandler(appInfo, null));
    final auth = AuthScenario(AuthScenarioKind.direct)
      ..saved = const AuthSession(
        accountId: 'synthetic-preview',
        phone: '13800000000',
        accessToken: 'synthetic-not-a-credential',
      );
    final journal = DiagnosticJournal(_MemoryStore());
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig.parse(environment: 'local', apiBaseUrl: ''),
        ),
        sessionStoreProvider.overrideWithValue(auth),
        diagnosticJournalProvider.overrideWithValue(journal),
      ],
    );
    addTearDown(() {
      container.dispose();
      journal.close();
    });
    final session = container.read(sessionControllerProvider.notifier);
    await session.restore();
    final installed = await container.read(installedAppSourceProvider).read();
    expect(installed.versionName, '1.0.52');
    expect(installed.versionCode, 45);
    final subscription = container.listen(
      logReportRepositoryProvider,
      (_, __) {},
    );
    final repository = subscription.read();
    expect(repository, isA<ZipLogRepository>());
    expect((repository as ZipLogRepository).journal, same(journal));
    // Empty config prevents any network request; the default must not succeed as MOCK.
    await expectLater(
      repository.upload(await repository.prepare()),
      throwsA(ApiFailure.unavailable),
    );
    subscription.close();
    await session.signOut();
    expect(
      () => container.read(logReportRepositoryProvider),
      throwsA(anything),
    );
  });
}

class _MemoryStore implements DiagnosticStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String next) async {
    value = next;
  }
}
