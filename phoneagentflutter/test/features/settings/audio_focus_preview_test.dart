import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/settings/presentation/pages/audio_focus_preview_page.dart';

void main() {
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: AudioFocusPreviewPage()));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('SDK holds playback until release at $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await open(tester);
      await tap(tester, find.byKey(const ValueKey('recording-primary')).first);
      await tap(tester, find.text('开始合成 SDK 采集'));
      expect(find.text('SDK：采集占用中'), findsOneWidget);
      expect(find.text('普通：paused · 翻译：ready'), findsOneWidget);
      await tap(tester, find.text('开始克隆试听（MOCK）'));
      expect(find.text('克隆试听中（MOCK）'), findsNothing);
      await tap(tester, find.text('取消采集（暂不释放）'));
      expect(find.text('SDK：等待 SDK 释放'), findsOneWidget);
      await tap(tester, find.text('开始克隆试听（MOCK）'));
      expect(find.text('克隆试听中（MOCK）'), findsNothing);
      await tap(tester, find.text('模拟 SDK 回调并释放'));
      expect(find.text('SDK：未采集'), findsOneWidget);
      await tap(tester, find.text('开始克隆试听（MOCK）'));
      expect(find.text('克隆试听中（MOCK）'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
    testWidgets('shared record cards switch through clone at $width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await open(tester);
      await tap(tester, find.byKey(const ValueKey('recording-primary')).first);
      expect(find.text('普通：playing · 翻译：ready'), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('recording-primary')).last);
      expect(find.text('普通：paused · 翻译：playing'), findsOneWidget);
      await tap(tester, find.text('开始克隆试听（MOCK）'));
      expect(find.text('普通：paused · 翻译：paused'), findsOneWidget);
      expect(find.text('克隆试听中（MOCK）'), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('recording-primary')).first);
      expect(find.text('普通：playing · 翻译：paused'), findsOneWidget);
      expect(find.text('开始克隆试听（MOCK）'), findsOneWidget);
      await tap(tester, find.text('停止全部合成播放'));
      expect(find.text('所有合成播放已停止'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('leaving while SDK active closes synthetic resources', (
    tester,
  ) async {
    await open(tester);
    await tap(tester, find.text('开始合成 SDK 采集'));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('stop failure is visible; retry does not overlap playback', (
    tester,
  ) async {
    await open(tester);
    await tap(tester, find.byKey(const ValueKey('recording-primary')).first);
    await tap(tester, find.text('模拟普通录音停止失败'));
    await tap(tester, find.text('开始克隆试听（MOCK）'));
    expect(find.text('切换失败：旧音频尚未确认停止，未启动第二个播放'), findsOneWidget);
    expect(find.text('普通：playing · 翻译：ready'), findsOneWidget);
    await tap(tester, find.text('模拟普通录音停止失败'));
    await tap(tester, find.text('开始克隆试听（MOCK）'));
    expect(find.text('克隆试听中（MOCK）'), findsOneWidget);
    expect(find.text('普通：paused · 翻译：ready'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
