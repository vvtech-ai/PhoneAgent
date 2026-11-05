import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/settings/presentation/pages/agent_context_preview_page.dart';
import 'package:phone_agent/features/settings/presentation/controller/agent_context_preview_controller.dart';

void main() {
  test(
    'synthetic source reuses builder and respects refreshed inputs',
    () async {
      final controller = AgentContextPreviewController();
      addTearDown(controller.dispose);
      await controller.prepare();
      expect(
        (controller.result['currentTime'] as Map)['isoDateTime'],
        '2026-09-19T07:59:00.000+08:00',
      );
      controller.setZone('Asia/Kathmandu');
      controller.setMode('读取失败');
      controller.advanceDay();
      await controller.prepare();
      expect(
        (controller.result['currentTime'] as Map)['isoDateTime'],
        '2026-09-20T05:44:00.000+05:45',
      );
      expect(
        (controller.result['permissionStatus'] as Map)['microphone'],
        'UNAVAILABLE',
      );
      expect(
        (controller.result['permissionStatus'] as Map)['document_picker'],
        'OK',
      );
      expect(controller.turns, 2);
    },
  );
  testWidgets('mobile preview has explicit MOCK and per-turn result', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: AgentContextPreviewPage()));
    expect(find.textContaining('MOCK'), findsOneWidget);
    await tester.tap(find.text('组装下一轮上下文'));
    await tester.pumpAndSettle();
    expect(find.textContaining('已组装 1 轮'), findsOneWidget);
    expect(
      find.textContaining('2026-09-19T07:59:00.000+08:00'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
