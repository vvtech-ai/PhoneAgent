import 'support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/app_call_record_providers.dart';
import 'package:phone_agent/app/contact_providers.dart';
import 'package:phone_agent/app/developer_list_providers.dart';
import 'package:phone_agent/app/outbound_number_providers.dart';
import 'package:phone_agent/app/phone_agent_app.dart';
import 'package:phone_agent/features/dialer/domain/dial_recent_call.dart';
import 'package:phone_agent/features/settings/data/preview_outbound_number_repository.dart';
import 'package:phone_agent/features/settings/presentation/pages/developer_tools_route.dart';
import '../tool/previews/migration_workbench.dart';
import '../tool/previews/workbench_catalog.dart';

void main() {
  for (final width in [320.0, 430.0]) {
    testWidgets('formal developer flow is isolated and continuous $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MigrationWorkbench(
          scenes: [workbenchScenes.singleWhere((s) => s.id == 'app')],
        ),
      );
      Future<void> tap(Finder target) async {
        await tester.pumpUntilUiSettled();
        if (find.byType(SnackBar).evaluate().isNotEmpty) {
          // Success/network notices temporarily cover the floating tab bar.
          await tester.pump(const Duration(seconds: 5));
          await tester.pumpUntilUiSettled();
        }
        if (target.evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            target,
            160,
            scrollable: find.byType(Scrollable).last,
          );
        }
        // Scroll controls above the floating bottom navigation before tapping.
        await Scrollable.ensureVisible(tester.element(target), alignment: 0.35);
        await tester.pumpUntilUiSettled();
        await tester.tap(target);
        await tester.pumpUntilUiSettled();
        expect(tester.takeException(), isNull);
      }

      Future<void> key(String id) => tap(find.byKey(ValueKey(id)));
      Future<void> back() async {
        if (find.byTooltip('返回').evaluate().isNotEmpty) {
          await tester.tap(find.byTooltip('返回'));
        } else {
          await tester.pageBack();
        }
        await tester.pumpUntilUiSettled();
      }

      Future<void> unlock() async {
        await tap(find.bySemanticsLabel('打开拨号盘'));
        for (final digit in '20142014*#'.split('')) {
          await key('dial-key-$digit');
        }
        await key('dial-call');
        expect(find.text('开发者功能已开启，请返回设置查看'), findsOneWidget);
        await key('dial-close');
        await key('tab-3');
        await key('settings-developer');
      }

      await key('scene-app');
      await unlock();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PhoneAgentApp)),
      );
      expect(find.byType(DeveloperToolsRoute), findsOneWidget);
      expect(find.text('固定外呼号码加载失败，请重试读取'), findsNothing);
      expect(find.text('尚未配置固定外呼号码'), findsOneWidget);
      final repository =
          container.read(outboundNumberRepositoryProvider)
              as PreviewOutboundNumberRepository;
      Future<void> edit() async {
        await tester.drag(find.byType(ListView).last, const Offset(0, 1800));
        await tester.pumpUntilUiSettled();
        await tap(find.text('固定外呼号码'));
      }

      final input = find.byKey(const Key('outbound-number-input'));
      await edit();
      await tester.enterText(input, '+12025550101');
      repository.failWrite = true;
      await tap(find.text('保存'));
      expect(find.text('保存结果未确认，可重新读取核对或再次保存'), findsOneWidget);
      expect(tester.widget<TextField>(input).controller!.text, '+12025550101');
      repository.failWrite = false;
      await tap(find.text('保存'));
      expect(repository.value.number, '+12025550101');
      await edit();
      expect(tester.widget<TextField>(input).controller!.text, '+12025550101');
      await tester.enterText(input, '+12025550102');
      await back();
      await edit();
      expect(tester.widget<TextField>(input).controller!.text, '+12025550101');
      await tap(find.text('删除固定外呼号码'));
      expect(repository.value.number, isEmpty);
      expect(repository.deletes, 1);
      await edit();
      expect(tester.widget<TextField>(input).controller!.text, isEmpty);
      await tester.enterText(input, '+12025550103');
      await tap(find.text('保存'));

      final records = container.read(appCallRecordRepositoryProvider)!;
      await records.append(
        const DialRecentCall(
          id: 'developer-synthetic',
          phone: '+12025550101',
          startedAtMillis: 1,
          source: DialRecentSource.app,
        ),
      );
      await key('developer-list-filled');
      expect(await records.load(), isEmpty);
      expect(container.read(developerListControllerProvider).failed, false);
      expect(container.read(contactsControllerProvider).contacts, isNotEmpty);
      await key('developer-list-empty');
      expect(container.read(contactsControllerProvider).contacts, isEmpty);
      await tap(find.text('重置'));
      expect(find.byKey(const Key('translation-model-open')), findsOneWidget);
      await key('dial-close');
      expect(find.byType(DeveloperToolsRoute), findsOneWidget);

      await key('developer-network-offline');
      await back();
      await key('tab-0');
      await key('skill-restaurant_booking');
      expect(find.text('无网络连接'), findsOneWidget);
      await tap(find.text('关闭'));
      await key('tab-3');
      await key('settings-developer');
      await key('developer-network-normal');
      await edit();
      expect(tester.widget<TextField>(input).controller!.text, '+12025550103');
      await back();
      await back();
      await key('settings-logout');
      await tap(find.byKey(const ValueKey('logout-confirm')));
      await tester.enterText(
        find.byKey(const ValueKey('loginPhone')),
        '13800000000',
      );
      await tester.enterText(find.byKey(const ValueKey('loginCode')), '123456');
      await key('loginAgreement');
      await key('loginBtn');
      await key('tab-3');
      await key('settings-developer');
      expect(find.text('尚未配置固定外呼号码'), findsOneWidget);
      expect(
        identical(container.read(outboundNumberRepositoryProvider), repository),
        false,
      );

      await key('workbench-home');
      await key('scene-app');
      await key('tab-3');
      expect(find.byKey(const Key('settings-developer')), findsNothing);
      await unlock();
      expect(find.text('尚未配置固定外呼号码'), findsOneWidget);
      await key('workbench-home');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpUntilUiSettled();
      expect(tester.takeException(), isNull);
    });
  }
}
