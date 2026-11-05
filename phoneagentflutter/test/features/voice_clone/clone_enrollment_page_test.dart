import 'package:flutter/material.dart';
import 'package:phone_agent/features/voice_clone/presentation/widgets/native_clone_controls.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/voice_clone/data/preview_clone_enrollment_port.dart';
import 'package:phone_agent/features/voice_clone/presentation/pages/clone_enrollment_page.dart';

Future<void> tap(WidgetTester tester, String text) async {
  final target = find.text(text);
  await tester.ensureVisible(target.last);
  await tester.tap(target.last);
  await tester.pumpAndSettle();
}

Future<void> open(WidgetTester tester, ClonePreviewScenario scenario) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => CloneEnrollmentPreviewPage(
                  port: PreviewCloneEnrollmentPort(
                    scenario,
                    delay: Duration.zero,
                  ),
                ),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tap(tester, 'Open');
}

Future<void> identity(WidgetTester tester) async {
  await tester.tap(find.byType(CloneCheckRow));
  await tester.pumpAndSettle();
  await tap(tester, '开始认证');
  await tap(tester, '填入合成测试数据');
  await tap(tester, '开始人脸跟读认证');
}

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('flow, unconfirmed back, rerecord and confirm at $width', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 720);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await open(tester, ClonePreviewScenario.success);
      final start = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '开始认证'),
      );
      expect(start.onPressed, isNull);
      await identity(tester);
      expect(find.text('声音克隆已完成'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('确认返回？'), findsOneWidget);
      await tap(tester, '继续完成');
      await tap(tester, '重新录制');
      expect(find.text('确认重新录制？'), findsOneWidget);
      await tap(tester, '取消');
      await tester.tap(find.byKey(const Key('clone-preview')));
      await tester.pumpAndSettle();
      await tap(tester, '设为默认声音');
      expect(find.text('演练已确认，真实音色未改变'), findsOneWidget);
      await tap(tester, '完成并返回');
      expect(find.text('Open'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'replacement dialog cancel restores editable form then confirms',
    (tester) async {
      await open(tester, ClonePreviewScenario.replacement);
      await identity(tester);
      expect(find.text('将替换当前认证身份'), findsOneWidget);
      await tap(tester, '取消');
      await tap(tester, '开始人脸跟读认证');
      await tap(tester, '继续并替换');
      expect(find.text('声音克隆已完成'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tap(tester, '确认返回');
      expect(find.text('Open'), findsOneWidget);
    },
  );
  testWidgets('verification failure returns clean form and can restart', (
    tester,
  ) async {
    await open(tester, ClonePreviewScenario.verificationFailure);
    await identity(tester);
    expect(find.byKey(const ValueKey('clone-flow-error')), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      isEmpty,
    );
    await tap(tester, '填入合成测试数据');
    await tap(tester, '开始人脸跟读认证');
    expect(find.text('声音克隆已完成'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
