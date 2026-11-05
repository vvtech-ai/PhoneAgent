import 'package:phone_agent/core/design/native_business_dialog.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/online_entry_providers.dart';
import 'package:phone_agent/features/settings/domain/network_availability.dart';
import 'package:phone_agent/features/settings/presentation/pages/developer_network_preview_page.dart';
import 'package:phone_agent/features/settings/presentation/widgets/online_entry_guard.dart';
import 'online_entry_controller_test.dart' show SampleSource;

void main() {
  Future<void> press(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  Future<void> open(
    WidgetTester tester,
    SampleSource source,
    VoidCallback onAllowed,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          networkAvailabilitySourceProvider.overrideWithValue(source),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Builder(
                      builder: (context) => Scaffold(
                        appBar: AppBar(title: const Text('本次入口')),
                        body: TextButton(
                          onPressed: () async {
                            if (await allowOnlineEntry(context)) onAllowed();
                          },
                          child: const Text('进入在线业务'),
                        ),
                      ),
                    ),
                  ),
                ),
                child: const Text('打开测试页'),
              ),
            ),
          ),
        ),
      ),
    );
    await press(tester, '打开测试页');
  }

  testWidgets(
    'OS offline retries after recovery without automatically replaying',
    (tester) async {
      var entered = 0;
      final source = SampleSource()..value = NetworkAvailability.unavailable;
      await open(tester, source, () => entered++);
      await press(tester, '进入在线业务');
      expect(find.text('系统当前没有可用网络，请检查网络设置后重试'), findsOneWidget);
      source.value = NetworkAvailability.available;
      await press(tester, '重试');
      expect(find.byType(NativeBusinessDialog), findsNothing);
      expect(entered, 0);
      await press(tester, '进入在线业务');
      expect(entered, 1);
      expect(source.reads, 3);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'duplicate entry shares no action; route pop suppresses initial late sample',
    (tester) async {
      var entered = 0;
      final source = SampleSource()..pending = Completer<NetworkAvailability>();
      await open(tester, source, () => entered++);
      await tester.tap(find.text('进入在线业务'));
      await tester.tap(find.text('进入在线业务'));
      await tester.pump();
      expect(source.reads, 1);
      await tester.binding.handlePopRoute();
      // Complete during reverse animation while old context can still be mounted.
      source.pending!.complete(NetworkAvailability.available);
      await tester.pumpAndSettle();
      expect(entered, 0);
      expect(find.text('打开测试页'), findsOneWidget);
      source.pending = null;
      await press(tester, '打开测试页');
      await press(tester, '进入在线业务');
      expect(entered, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'closing retry dialog invalidates late sample and releases next entry',
    (tester) async {
      var entered = 0;
      final source = SampleSource()..value = NetworkAvailability.unavailable;
      await open(tester, source, () => entered++);
      await press(tester, '进入在线业务');
      source.pending = Completer<NetworkAvailability>();
      await tester.tap(find.text('重试'));
      await tester.pump();
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '检查中'))
            .onPressed,
        isNull,
      );
      await press(tester, '关闭');
      source.pending!.complete(NetworkAvailability.available);
      await tester.pumpAndSettle();
      expect(entered, 0);
      source.pending = null;
      source.value = NetworkAvailability.available;
      await press(tester, '进入在线业务');
      expect(entered, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unknown or throwing source attempts business without claiming available',
    (tester) async {
      var entered = 0;
      final source = SampleSource()..value = NetworkAvailability.unknown;
      await open(tester, source, () => entered++);
      await press(tester, '进入在线业务');
      source.fail = true;
      await press(tester, '进入在线业务');
      expect(entered, 2);
      expect(find.byType(NativeBusinessDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'system fixture is isolated and covers offline unknown and failed sampling',
    (tester) async {
      final parent = ProviderContainer(
        overrides: [
          networkAvailabilitySourceProvider.overrideWith(
            (_) => throw StateError('No real device allowed'),
          ),
        ],
      );
      addTearDown(parent.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: parent,
          child: const MaterialApp(home: DeveloperNetworkPreviewPage()),
        ),
      );
      await press(tester, '系统离线');
      await press(tester, '首页新对话');
      expect(find.text('系统当前没有可用网络，请检查网络设置后重试'), findsOneWidget);
      await press(tester, '关闭');
      await press(tester, '检测未知');
      await press(tester, '首页新对话');
      expect(find.text('在线入口通过：1；最近：首页新对话'), findsOneWidget);
      await press(tester, '模拟检测异常');
      await press(tester, '任务恢复');
      expect(find.text('在线入口通过：2；最近：任务恢复'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
