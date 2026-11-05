import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/agent_location_providers.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/features/conversation/domain/context/agent_location.dart';
import 'package:phone_agent/features/settings/presentation/pages/agent_location_preview_page.dart';
import 'package:phone_agent/features/settings/presentation/widgets/developer_location_summary.dart';
import '../conversation/agent_location_test.dart' show LocationSource;

void main() {
  testWidgets('summary only observes shared Agent snapshot, no eager sample', (
    tester,
  ) async {
    final source = LocationSource()..value = AgentLocation(1, 2);
    final container = ProviderContainer(
      overrides: [
        loginEpochProvider.overrideWithValue(0),
        agentLocationSourceProvider.overrideWithValue(source),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: DeveloperLocationSummary()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(source.reads, 0);
    expect(find.text('未获取到位置信息'), findsOneWidget);
    await container.read(agentLocationProvider.notifier).context();
    await tester.pumpAndSettle();
    expect(find.text('1.0000, 2.0000'), findsOneWidget);
    expect(source.reads, 1);
  });
  for (final width in [320.0, 430.0]) {
    testWidgets(
      '$width preview uses shared cache and leaves primed parent untouched',
      (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final parentSource = LocationSource()..value = AgentLocation(1, 2);
        final parent = ProviderContainer(
          overrides: [
            loginEpochProvider.overrideWithValue(99),
            agentLocationSourceProvider.overrideWithValue(parentSource),
          ],
        );
        addTearDown(parent.dispose);
        await parent.read(agentLocationProvider.notifier).context();
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: parent,
            child: const MaterialApp(home: AgentLocationPreviewPage()),
          ),
        );
        await tester.pumpAndSettle();
        Future<void> press(String value) async {
          await tester.ensureVisible(find.text(value));
          await tester.tap(find.text(value));
          await tester.pumpAndSettle();
        }

        await press('坐标');
        await press('模拟一轮对话前读取');
        expect(find.text('22.5000, 114.0000'), findsOneWidget);
        await press('地址');
        await press('模拟一轮对话前读取');
        expect(find.text('22.5000, 114.0000'), findsOneWidget);
        expect(find.textContaining('取样次数：1；'), findsOneWidget);
        await press('推进3分钟（缓存到期）');
        await press('模拟一轮对话前读取');
        expect(find.text('合成地址 · 演练街道'), findsOneWidget);
        await press('失败');
        await press('推进3分钟（缓存到期）');
        await press('模拟一轮对话前读取');
        expect(find.text('合成地址 · 演练街道'), findsOneWidget);
        expect(parent.read(agentLocationProvider)?.lat, 1);
        expect(parentSource.reads, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
