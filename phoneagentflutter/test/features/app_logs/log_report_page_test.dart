import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/app_logs/domain/app_log_report.dart';
import 'package:phone_agent/features/app_logs/presentation/pages/log_report_page.dart';
import 'package:phone_agent/features/app_logs/presentation/pages/log_report_preview_page.dart';

void main() {
  for (final width in [320.0, 393.0]) {
    testWidgets(
      'remaining batch is explicit and never uploads automatically $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 667);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final port = _Port()..hasMore = true;
        await tester.pumpWidget(
          MaterialApp(home: LogReportPage(repository: port)),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('日志较多'), findsOneWidget);
        expect(port.uploads, 0);
        await tester.ensureVisible(find.text('上传诊断日志'));
        await tester.tap(find.text('上传诊断日志'));
        await tester.pumpAndSettle();
        expect(port.uploads, 1);
        port.hasMore = false;
        await tester.ensureVisible(find.text('继续准备剩余日志'));
        await tester.tap(find.text('继续准备剩余日志'));
        await tester.pumpAndSettle();
        expect(port.uploads, 1);
        expect(find.textContaining('日志较多'), findsNothing);
        await tester.ensureVisible(find.text('上传诊断日志'));
        await tester.tap(find.text('上传诊断日志'));
        await tester.pumpAndSettle();
        expect(port.uploads, 2);
        expect(find.text('继续准备剩余日志'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets(
      'real page prepares locally, explicit upload and return $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final port = _Port();
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => LogReportPage(repository: port),
                        ),
                      );
                    },
                    child: const Text('打开日志'),
                  ),
                );
              },
            ),
          ),
        );
        await tester.tap(find.text('打开日志'));
        await tester.pumpAndSettle();
        expect(find.textContaining('日志已准备：1 条'), findsOneWidget);
        expect(port.uploads, 0);
        await tester.tap(find.text('上传诊断日志'));
        await tester.pumpAndSettle();
        expect(find.text('日志上传成功'), findsOneWidget);
        expect(port.uploads, 1);
        expect(port.cleanups, 1);
        expect(find.text('上传诊断日志'), findsNothing);
        await tester.tap(find.text('返回'));
        await tester.pumpAndSettle();
        expect(find.text('打开日志'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('synthetic preview failure can retry without real dependencies', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: LogReportPreviewPage(failUpload: true)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('MOCK · 合成日志'), findsOneWidget);
    await tester.tap(find.text('模拟上传合成日志'));
    await tester.pumpAndSettle();
    expect(find.textContaining('上传结果未确认'), findsOneWidget);
    await tester.tap(find.text('模拟上传合成日志'));
    await tester.pumpAndSettle();
    expect(find.text('MOCK · 已完成压缩和模拟上传，没有发送真实日志'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets('cleanup error exposes cleanup-only retry', (tester) async {
    final port = _Port()..cleanupFails = true;
    await tester.pumpWidget(MaterialApp(home: LogReportPage(repository: port)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('上传诊断日志'));
    await tester.pumpAndSettle();
    expect(find.textContaining('日志已上传，本地清理失败'), findsOneWidget);
    port.cleanupFails = false;
    await tester.tap(find.text('仅重试本地清理'));
    await tester.pumpAndSettle();
    expect(port.uploads, 1);
    expect(port.cleanups, 2);
    expect(find.text('日志上传成功'), findsOneWidget);
  });
}

class _Port implements AppLogRepository {
  int uploads = 0, cleanups = 0;
  bool cleanupFails = false;
  bool hasMore = false;
  @override
  Future<AppLogBundle> prepare() async => AppLogBundle(
    watermark: 1,
    count: 1,
    bytes: Uint8List.fromList([1, 2]),
    fileName: 'synthetic.zip',
    hasMore: hasMore,
  );
  @override
  Future<void> upload(AppLogBundle bundle) async {
    uploads++;
  }

  @override
  Future<void> acknowledge(AppLogBundle bundle) async {
    cleanups++;
    if (cleanupFails) throw StateError('synthetic');
  }
}
