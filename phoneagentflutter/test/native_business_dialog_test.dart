import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/design/native_business_dialog.dart';

const _captureDir = String.fromEnvironment('CAPTURE_DIALOG_DIR');
const _captureKey = Key('dialog-preview');

void main() {
  setUpAll(() async {
    if (_captureDir.isEmpty) return;
    final loader = FontLoader('DialogPreview')
      ..addFont(
        File(
          '/System/Library/Fonts/Supplemental/Arial Unicode.ttf',
        ).readAsBytes().then(ByteData.sublistView),
      );
    await loader.load();
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform long text keeps equal actions accessible at 2x', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 480);
      addTearDown(tester.view.reset);
      var confirmed = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (dialog) => NativeBusinessDialog(
                  title: '请确认此操作',
                  message: '这是一条较长的说明。' * 12,
                  confirmLabel: '继续重新认证',
                  dismissLabel: '取消',
                  onDismiss: () => Navigator.pop(dialog),
                  onConfirm: () {
                    confirmed = true;
                    Navigator.pop(dialog);
                  },
                ),
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      final confirm = find.widgetWithText(TextButton, '继续重新认证');
      await tester.ensureVisible(confirm);
      await tester.pumpAndSettle();
      final cancel = find.widgetWithText(TextButton, '取消');
      expect(tester.getSize(confirm), tester.getSize(cancel));
      expect(tester.getRect(confirm).bottom, lessThanOrEqualTo(480));
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(confirmed, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('single disabled action and blocked back retain modal', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (_) => const NativeBusinessDialog(
                title: '下载中',
                confirmLabel: '请稍候',
                onConfirm: null,
                showDismiss: false,
                allowBack: false,
                error: '合成错误状态',
              ),
            ),
            child: const Text('打开'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.byType(TextButton).hitTestable(), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '请稍候'))
          .onPressed,
      isNull,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('下载中'), findsOneWidget);
    expect(find.text('合成错误状态'), findsOneWidget);
  });

  for (final entry in [
    ('permission', '允许访问通讯录？', '用于选择联系人并发起通话任务', '继续授权', false),
    ('delete', '删除全部记忆？', '列表中的记忆将全部删除，删除后无法恢复。', '确认删除', true),
    ('logout', '退出登录？', '退出后将回到手机号登录页，当前账号数据仍会保留。', '退出', true),
    ('update', '发现新版本', '新版本：示例版本\n本次更新包含体验优化与问题修复。', '立即更新', false),
  ]) {
    testWidgets('shared visual ${entry.$1}', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 640);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            fontFamily: _captureDir.isEmpty ? null : 'DialogPreview',
          ),
          builder: (_, child) =>
              RepaintBoundary(key: _captureKey, child: child),
          home: Scaffold(
            backgroundColor: const Color(0xFFF1F5FA),
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (dialog) => NativeBusinessDialog(
                    title: entry.$2,
                    message: entry.$3,
                    confirmLabel: entry.$4,
                    kind: entry.$5
                        ? NativeDialogKind.confirmation
                        : NativeDialogKind.explanation,
                    danger: entry.$5,
                    dismissLabel: entry.$1 == 'permission'
                        ? '暂不'
                        : entry.$1 == 'update'
                        ? '稍后'
                        : '取消',
                    onDismiss: () => Navigator.pop(dialog),
                    onConfirm: () => Navigator.pop(dialog),
                  ),
                ),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      final shape =
          tester.widget<Dialog>(find.byType(Dialog)).shape
              as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(22));
      expect(tester.takeException(), isNull);
      if (_captureDir.isNotEmpty) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(_captureKey),
        );
        await tester.runAsync(() async {
          final picture = await boundary.toImage(pixelRatio: 2);
          final bytes = await picture.toByteData(
            format: ui.ImageByteFormat.png,
          );
          await File(
            '$_captureDir/${entry.$1}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          picture.dispose();
        });
      }
    });
  }
}
