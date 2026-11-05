import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/app_update/data/preview_update_install_port.dart';
import 'package:phone_agent/features/app_update/domain/app_update.dart';
import 'package:phone_agent/features/app_update/presentation/controller/update_install_controller.dart';
import 'package:phone_agent/features/app_update/presentation/pages/update_install_page.dart';
import 'package:phone_agent/features/app_update/presentation/pages/update_install_preview.dart';

Future<void> tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> finishDownload(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 600));
  }
}

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets(
      'shared download permission installer return and back at $width',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 640);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          const MaterialApp(home: UpdateInstallPreview()),
        );
        await tapText(tester, '正常下载与安装交接');
        expect(find.text('MOCK · 下载与安装演练'), findsOneWidget);
        await tapText(tester, '下载并安装');
        await finishDownload(tester);
        await tapText(tester, '模拟拒绝并返回');
        expect(find.text('尚未授权安装，可再次点击授权'), findsOneWidget);
        await tapText(tester, '去授权安装');
        await tapText(tester, '模拟已授权并返回');
        expect(find.text('已打开系统安装器，请在系统界面完成安装'), findsOneWidget);
        await tapText(tester, '模拟取消系统安装并返回');
        expect(find.text('安装未完成，可再次点击安装继续更新'), findsOneWidget);
        await tapText(tester, '继续安装');
        await tapText(tester, '模拟取消系统安装并返回');
        await tapText(tester, '稍后更新');
        await tester.pumpAndSettle();
        expect(find.text('正常下载与安装交接'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final scenario in ['下载失败后重试']) {
    testWidgets('$scenario uses same retry action', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: UpdateInstallPreview()));
      await tapText(tester, scenario);
      await tapText(tester, '下载并安装');
      await finishDownload(tester);
      expect(find.text('重新下载'), findsOneWidget);
      await tapText(tester, '重新下载');
      await finishDownload(tester);
      expect(find.text('去授权安装'), findsOneWidget);
      await tapText(tester, '稍后更新');
      await tester.pumpAndSettle();
      expect(find.text('MOCK · 更新安装场景'), findsOneWidget);
    });
  }
  testWidgets('paused network resumes then system back cancels and returns', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: UpdateInstallPreview()));
    await tapText(tester, '网络暂停后恢复');
    await tapText(tester, '下载并安装');
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('下载已暂停，等待网络恢复…'), findsOneWidget);
    await tapText(tester, '模拟网络恢复');
    await finishDownload(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('MOCK · 更新安装场景'), findsOneWidget);
  });
  testWidgets(
    'restore waits for explicit installation and force cannot dismiss',
    (tester) async {
      final port = PreviewUpdateInstallPort(UpdateInstallScenario.restored);
      final controller = UpdateInstallController(
        app: PreviewUpdateInstallPort.app,
        release: const AppUpdateRelease(
          hasUpdate: true,
          packageName: 'com.example.preview',
          versionName: '1.1.0',
          versionCode: 2,
          fileSize: 1024,
          forceUpdate: true,
        ),
        port: port,
        isCurrent: () => true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: UpdateInstallPage(
            controller: controller,
            disposeController: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('安装包已准备好'), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
      expect(find.text('稍后更新'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('继续安装'), findsOneWidget);
    },
  );
}
