import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/app_update_providers.dart';
import 'package:phone_agent/app/update_install_providers.dart';
import 'package:phone_agent/features/app_update/presentation/pages/startup_update_preview_page.dart';

void main() {
  Finder dialogText(String text) =>
      find.descendant(of: find.byType(Dialog), matching: find.text(text));
  Future<void> open(WidgetTester tester, String scenario) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          startupUpdateControllerProvider.overrideWith(
            (_) => throw StateError('Preview escaped to production scope'),
          ),
          updateInstallProvider.overrideWith(
            (_, __) => throw StateError('Preview used production installer'),
          ),
        ],
        child: const MaterialApp(home: StartupUpdateScenariosPage()),
      ),
    );
    await tester.tap(find.text(scenario));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  testWidgets(
    'nested mock scope survives force dialog and installation routes',
    (tester) async {
      await open(tester, '强制更新与安装取消');
      expect(find.text('发现重要版本更新'), findsOneWidget);
      expect(dialogText('MOCK · 版本请求次数：1'), findsOneWidget);
      await tester.tap(find.byKey(const Key('startup-update-install')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('update-install-status')), findsOneWidget);
      expect(find.text('MOCK · 版本请求次数：1'), findsWidgets);
      await tester.tap(dialogText('模拟服务端确认无需更新'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('update-install-status')), findsNothing);
      expect(find.text('发现重要版本更新'), findsNothing);
      expect(find.text('MOCK · 持久强制标记：false'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('same day stays on home without a version request', (
    tester,
  ) async {
    await open(tester, '当天已检查不重复弹出');
    expect(find.text('发现新版本'), findsNothing);
    expect(find.text('MOCK · 版本请求次数：0'), findsWidgets);
  });

  testWidgets(
    'offline force is not a cached lockout; repaired response gates',
    (tester) async {
      await open(tester, '强制标记下离线失败与重试');
      expect(find.text('发现重要版本更新'), findsNothing);
      expect(find.text('MOCK · 持久强制标记：true'), findsOneWidget);
      expect(find.text('MOCK · 版本请求次数：1'), findsWidgets);
      await tester.tap(find.text('模拟网络恢复并检查'));
      await tester.pumpAndSettle();
      expect(find.text('发现重要版本更新'), findsOneWidget);
      expect(dialogText('MOCK · 版本请求次数：2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('recovered download reaches verified ready without check API', (
    tester,
  ) async {
    await open(tester, '离线恢复已下载任务');
    expect(find.text('安装包已准备好'), findsOneWidget);
    expect(find.text('MOCK · 版本请求次数：0'), findsWidgets);
    await tester.tap(find.byKey(const Key('update-install-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('update-install-status')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'missing download refreshes metadata instead of empty URL begin',
    (tester) async {
      await open(tester, '恢复失败刷新下载信息');
      expect(find.text('刷新下载信息'), findsOneWidget);
      expect(find.text('MOCK · 版本请求次数：0'), findsWidgets);
      await tester.tap(find.text('刷新下载信息'));
      await tester.pumpAndSettle();
      expect(find.text('发现新版本'), findsOneWidget);
      expect(dialogText('MOCK · 版本请求次数：1'), findsOneWidget);
      await tester.tap(find.byKey(const Key('startup-update-install')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('update-install-status')), findsOneWidget);
      expect(find.text('下载并安装'), findsNothing);
      expect(find.text('刷新下载信息'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );
}
