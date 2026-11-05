import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/settings/presentation/pages/developer_preview_page.dart';
import 'package:phone_agent/features/settings/presentation/pages/service_preview_page.dart';
import 'package:phone_agent/features/settings/presentation/pages/settings_preview_gate.dart';
import 'package:phone_agent/features/settings/presentation/controller/service_preview_controller.dart';

void main() {
  testWidgets(
    'developer synthetic list/number/network/permission flows return safely',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: DeveloperPreviewPage()));
      await tester.scrollUntilVisible(find.text('清空列表'), 180);
      await tester.ensureVisible(find.text('清空列表'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('清空列表'));
      await tester.pump();
      expect(find.text('真实数据状态（演练）：已模拟清空，真实列表未改变'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('固定外呼号码'), 180);
      await tester.ensureVisible(find.text('固定外呼号码'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('固定外呼号码'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pump();
      expect(find.text('请输入外呼号码'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '2025550123');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.text('MOCK · 2025550123'), findsOneWidget);
      await tester.tap(find.text('固定外呼号码'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除固定外呼号码'));
      await tester.pumpAndSettle();
      expect(find.text('未配置（MOCK）'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('弱网'), 250);
      await tester.tap(find.text('弱网'));
      await tester.pump();
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '弱网'))
            .selected,
        isTrue,
      );
      await tester.ensureVisible(find.text('重置所有权限'));
      await tester.tap(find.text('重置所有权限'));
      await tester.pump();
      expect(find.text('MOCK · 模拟权限记录已重置；系统权限未改变'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('WebRTC sub-controls respect build visibility flag', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: DeveloperPreviewPage(showWebRtcControls: false)),
    );
    expect(find.text('国内强制 WebRTC'), findsNothing);
    expect(find.text('国外服务器'), findsNothing);
  });
  for (final kind in PreviewService.values) {
    testWidgets('explicit gate to $kind preview, progress and back', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsPreviewGate(
            title: '服务尚未接入',
            explanation: '不会真实执行',
            preview: ServicePreviewPage(service: kind),
          ),
        ),
      );
      expect(find.text('MOCK · 隔离交互演练'), findsNothing);
      await tester.tap(find.text('进入隔离交互演练（MOCK）'));
      await tester.pumpAndSettle();
      expect(find.text('MOCK · 隔离交互演练'), findsOneWidget);
      await tester.tap(
        find.text(kind == PreviewService.logs ? '模拟上报 / 重试' : '模拟检查更新'),
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(
        find.text(
          kind == PreviewService.logs
              ? 'MOCK · 上报成功，未上传任何真实文件'
              : 'MOCK · 发现可用版本，等待下载',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('退出演练'));
      await tester.pumpAndSettle();
      expect(find.text('服务尚未接入'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
