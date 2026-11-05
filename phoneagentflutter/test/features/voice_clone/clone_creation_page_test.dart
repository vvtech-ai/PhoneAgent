import 'package:flutter/material.dart';
import 'package:phone_agent/features/voice_clone/presentation/widgets/native_clone_controls.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/voice_clone/data/preview_clone_creation_port.dart';
import 'package:phone_agent/features/voice_clone/presentation/pages/clone_creation_preview_page.dart';

void main() {
  Future<void> tap(WidgetTester tester, String text) async {
    final target = find.text(text).last;
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester, CloneCreationScenario scenario) async {
    await tester.pumpWidget(
      MaterialApp(home: CloneCreationPreviewPage(scenario: scenario)),
    );
    await tap(tester, '选择声音克隆模型');
  }

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('reuse flow and sheet dismissal at $width', (tester) async {
      tester.view.physicalSize = Size(width, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await open(tester, CloneCreationScenario.reusable);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tap(tester, '选择声音克隆模型');
      await tap(tester, 'Seeduplex V3');
      expect(find.text('克隆模型：Seeduplex V3'), findsOneWidget);
      expect(find.byType(CloneCheckRow), findsNothing);
      expect(find.text('声音克隆已完成'), findsOneWidget);
      await tap(tester, '重新录制');
      await tap(tester, '取消');
      await tap(tester, '重新录制');
      await tap(tester, '继续重新录制');
      expect(find.text('声音克隆已完成'), findsOneWidget);
      await tap(tester, '设为默认声音');
      await tap(tester, '完成并返回');
      expect(find.text('创建克隆入口演练'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('existing clone cancel then confirm goes to full auth', (
    tester,
  ) async {
    await open(tester, CloneCreationScenario.existing);
    await tap(tester, 'QwenOmniPlus');
    expect(find.text('重新认证并克隆音色？'), findsOneWidget);
    await tap(tester, '取消');
    await tap(tester, 'QwenOmniPlus');
    await tap(tester, '继续重新认证');
    expect(find.text('克隆模型：QwenOmniPlus'), findsOneWidget);
    expect(find.byType(CloneCheckRow), findsOneWidget);
    expect(find.text('声音克隆已完成'), findsNothing);
  });
  testWidgets('expired recording goes back to consent, not generated success', (
    tester,
  ) async {
    await open(tester, CloneCreationScenario.expired);
    await tap(tester, 'QwenOmniPlus');
    expect(find.textContaining('认证录音或身份已失效'), findsOneWidget);
    expect(find.byType(CloneCheckRow), findsOneWidget);
    expect(find.text('声音克隆已完成'), findsNothing);
  });
  testWidgets('insufficient points stay in picker without generating', (
    tester,
  ) async {
    await open(tester, CloneCreationScenario.insufficient);
    await tap(tester, 'QwenOmniPlus');
    expect(find.textContaining('积分不足'), findsOneWidget);
    expect(find.text('声音克隆已完成'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('创建克隆入口演练'), findsOneWidget);
  });
  testWidgets('model load failure retries without closing base route', (
    tester,
  ) async {
    await open(tester, CloneCreationScenario.loadFailure);
    expect(find.text('重试加载'), findsNothing);
    await tap(tester, '×');
    expect(find.text('创建克隆入口演练'), findsOneWidget);
    await tap(tester, '选择声音克隆模型');
    expect(find.text('QwenOmniPlus'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'failed existing candidate retries read then explicitly recreates',
    (tester) async {
      await open(tester, CloneCreationScenario.failed);
      await tap(tester, 'QwenOmniPlus');
      expect(find.text('重新读取候选状态'), findsOneWidget);
      await tap(tester, '重新读取候选状态');
      expect(find.text('声音克隆已完成'), findsNothing);
      await tap(tester, '重新录制');
      await tap(tester, '继续重新录制');
      expect(find.text('声音克隆已完成'), findsOneWidget);
      expect(find.byType(CloneCheckRow), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('确认返回？'), findsNothing);
      expect(find.text('创建克隆入口演练'), findsOneWidget);
    },
  );
}
