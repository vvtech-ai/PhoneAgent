import 'package:phone_agent/core/design/native_business_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/developer_network_providers.dart';
import 'package:phone_agent/app/online_entry_providers.dart';
import 'package:phone_agent/features/settings/domain/network_availability.dart';
import 'package:phone_agent/features/settings/domain/developer_network_mode.dart';
import 'package:phone_agent/features/settings/presentation/pages/developer_network_preview_page.dart';
import 'package:phone_agent/features/settings/presentation/widgets/online_entry_guard.dart';

void main() {
  test('only offline blocks; state is process/container-local', () {
    for (final mode in DeveloperNetworkMode.values) {
      expect(mode.blocksOnlineEntry, mode == DeveloperNetworkMode.offline);
    }
    final first = ProviderContainer(), second = ProviderContainer();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    first.read(developerNetworkModeProvider.notifier).state =
        DeveloperNetworkMode.offline;
    expect(
      second.read(developerNetworkModeProvider),
      DeveloperNetworkMode.normal,
    );
  });

  Future<void> press(WidgetTester tester, String text) async {
    final item = find.text(text);
    await Scrollable.ensureVisible(tester.element(item), alignment: .35);
    await tester.pumpAndSettle();
    expect(item.hitTestable(), findsOneWidget);
    await tester.tap(item);
    await tester.pumpAndSettle();
  }

  for (final width in [320.0, 430.0]) {
    testWidgets('$width preview covers all entries and system exception', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: DeveloperNetworkPreviewPage()),
        ),
      );
      await tester.pumpAndSettle();
      await press(tester, '断网');
      for (final name in ['首页新对话', '任务恢复', '联系人需求', '翻译呼叫']) {
        await press(tester, name);
        expect(find.text('无网络连接'), findsOneWidget);
        await press(tester, '重试');
        expect(find.text('当前仍为断网模拟，可在开发者功能切换'), findsOneWidget);
        await press(tester, '关闭');
      }
      expect(find.text('在线入口通过：0；最近：未操作'), findsOneWidget);
      await press(tester, '普通系统拨号（MOCK）');
      expect(find.text('系统拨号入口通过：1（未拨号）'), findsOneWidget);
      await press(tester, '弱网');
      await press(tester, '首页新对话');
      expect(find.text('在线入口通过：1；最近：首页新对话'), findsOneWidget);
      await press(tester, '正常');
      await press(tester, '任务恢复');
      expect(find.text('在线入口通过：2；最近：任务恢复'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'child dialog keeps scope and retry never replays after mode change',
    (tester) async {
      final parent = ProviderContainer(
        overrides: [
          networkAvailabilitySourceProvider.overrideWithValue(
            const UnknownNetworkAvailability(),
          ),
        ],
      );
      addTearDown(parent.dispose);
      parent.read(onlineEntryControllerProvider);
      // Prime parent before entering a nested scope (past regression pattern).
      expect(
        parent.read(developerNetworkModeProvider),
        DeveloperNetworkMode.normal,
      );
      ProviderContainer? child;
      var executions = 0;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: parent,
          child: MaterialApp(
            home: ProviderScope(
              overrides: [
                developerNetworkModeProvider.overrideWith(
                  (_) => DeveloperNetworkMode.offline,
                ),
              ],
              child: Builder(
                builder: (context) {
                  child = ProviderScope.containerOf(context);
                  return Scaffold(
                    body: TextButton(
                      onPressed: () async {
                        if (await allowOnlineEntry(context)) {
                          executions++;
                        }
                      },
                      child: const Text('进入'),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await press(tester, '进入');
      await press(tester, '重试');
      expect(find.text('当前仍为断网模拟，可在开发者功能切换'), findsOneWidget);
      child!.read(developerNetworkModeProvider.notifier).state =
          DeveloperNetworkMode.normal;
      await press(tester, '重试');
      expect(find.byType(NativeBusinessDialog), findsNothing);
      expect(executions, 0);
      await press(tester, '进入');
      expect(executions, 1);
      child!.read(developerNetworkModeProvider.notifier).state =
          DeveloperNetworkMode.offline;
      await press(tester, '进入');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(executions, 1);
      expect(
        parent.read(developerNetworkModeProvider),
        DeveloperNetworkMode.normal,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('preview does not inherit or overwrite formal offline mode', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(developerNetworkModeProvider.notifier).state =
        DeveloperNetworkMode.offline;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: DeveloperNetworkPreviewPage()),
      ),
    );
    await press(tester, '首页新对话');
    expect(find.text('在线入口通过：1；最近：首页新对话'), findsOneWidget);
    await press(tester, '弱网');
    expect(
      container.read(developerNetworkModeProvider),
      DeveloperNetworkMode.offline,
    );
    await tester.pumpWidget(const SizedBox());
    expect(
      container.read(developerNetworkModeProvider),
      DeveloperNetworkMode.offline,
    );
  });
}
