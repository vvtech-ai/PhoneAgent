import 'package:flutter/material.dart';
import 'package:phone_agent/features/voice_clone/presentation/widgets/native_clone_controls.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/voice_clone/data/preview_clone_flow.dart';
import 'package:phone_agent/features/voice_clone/presentation/pages/clone_flow_preview_page.dart';

Future<void> tap(WidgetTester tester, String text) async {
  final target = find.text(text).last;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> open(WidgetTester tester, CloneFlowScenario scenario) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => CloneFlowPreviewPage(scenario: scenario),
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

Future<void> submit(WidgetTester tester) async {
  await tester.tap(find.byType(CloneCheckRow));
  await tester.pumpAndSettle();
  await tap(tester, '开始认证');
  await tap(tester, '填入合成测试数据');
  await tap(tester, '开始人脸跟读认证');
}

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets(
      'shared production flow, cancel back/rerecord, confirm at $width',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 720);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        await open(tester, CloneFlowScenario.success);
        await submit(tester);
        expect(find.text('声音克隆已完成'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('确认返回？'), findsOneWidget);
        await tester.tapAt(const Offset(8, 8));
        await tester.pumpAndSettle();
        expect(find.text('确认返回？'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('确认返回？'), findsOneWidget);
        await tap(tester, '继续完成');
        await tap(tester, '重新录制');
        await tap(tester, '取消');
        await tap(tester, '设为默认声音');
        expect(find.text('演练已确认，真实音色未改变'), findsOneWidget);
        await tap(tester, '完成并返回');
        expect(find.text('Open'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('unknown confirmation exposes sync, not another submit', (
    tester,
  ) async {
    await open(tester, CloneFlowScenario.confirmationUnknown);
    await submit(tester);
    await tap(tester, '设为默认声音');
    expect(find.text('同步本次状态'), findsNothing);
    expect(find.text('音色状态尚未同步，请稍后重试'), findsOneWidget);
    await tap(tester, '设为默认声音');
    expect(find.text('演练已确认，真实音色未改变'), findsOneWidget);
  });
  testWidgets('recording retry remains separate from confirmed success', (
    tester,
  ) async {
    await open(tester, CloneFlowScenario.saveFailure);
    await submit(tester);
    await tap(tester, '设为默认声音');
    expect(find.text('演练已确认，真实音色未改变'), findsOneWidget);
    await tap(tester, '仅重试保存认证录音');
    expect(find.text('仅重试保存认证录音'), findsNothing);
  });
}
