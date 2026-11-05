import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/design/native_notice.dart';
import 'package:phone_agent/features/translation/presentation/pages/livekit_translation_preview_page.dart';

void main() {
  tearDown(dismissNativeNotice);
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LiveKitTranslationPreviewPage()),
    );
    await tester.tap(find.text('开始双就绪演练'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('AppAudio fallback shares controls and returns at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, width == 320 ? 568 : 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(home: LiveKitTranslationPreviewPage()),
      );
      await tester.tap(find.text('开始AppAudio回退演练'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('采集未启动'), findsOneWidget);
      await tester.tap(find.text('AppAudio就绪'));
      await tester.pumpAndSettle();
      expect(find.text('正在振铃'), findsOneWidget);
      expect(find.textContaining('采集未启动'), findsOneWidget);
      await tester.tap(find.text('采集就绪'));
      await tester.pump();
      expect(find.textContaining('采集已就绪'), findsOneWidget);
      await tester.tap(find.text('模拟接通'));
      await tester.pump();
      await tester.tap(find.text('模拟双语'));
      await tester.pump();
      expect(find.text('你好，有什么可以帮助你？'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('静音'));
      await tester.pump();
      await tester.tap(find.text('模拟译音'));
      await tester.pump();
      expect(find.textContaining('译音1帧'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('扬声器'));
      await tester.pump();
      expect(
        tester
            .widget<Semantics>(find.bySemanticsLabel('扬声器'))
            .properties
            .toggled,
        isTrue,
      );
      await tester.tap(find.bySemanticsLabel('拨号盘'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('translation-dtmf-1')));
      await tester.pumpAndSettle();
      const unsupportedDtmf = '当前媒体通道不支持发送按键';
      expect(find.byKey(const ValueKey('nativeNoticeSurface')), findsOneWidget);
      expect(find.text(unsupportedDtmf), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('nativeNoticeSurface')), findsNothing);
      expect(find.textContaining(unsupportedDtmf), findsNothing);
      expect(find.bySemanticsLabel('挂断'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.bySemanticsLabel('挂断'));
      await tester.pumpAndSettle();
      expect(find.textContaining('merchant 1 / hangup 1'), findsOneWidget);
      expect(
        find.textContaining('room.close → AppAudio fallback'),
        findsOneWidget,
      );
      expect(find.textContaining('音频占用：已释放'), findsOneWidget);
    });
    testWidgets('double ready, subtitle, controls and release at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, width == 320 ? 568 : 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await open(tester);
      await tester.tap(find.text('服务就绪'));
      await tester.pump();
      expect(find.bySemanticsLabel('挂断'), findsOneWidget);
      expect(find.text('正在振铃'), findsNothing);
      await tester.tap(find.text('房间就绪'));
      await tester.pumpAndSettle();
      expect(find.text('正在振铃'), findsOneWidget);
      expect(
        tester
            .widget<Semantics>(find.bySemanticsLabel('扬声器'))
            .properties
            .toggled,
        isFalse,
      );
      await tester.tap(find.text('模拟接通'));
      await tester.pump();
      await tester.tap(find.text('模拟双语'));
      await tester.pump();
      expect(find.text('你好，有什么可以帮助你？'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('静音'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('扬声器'));
      await tester.pump();
      expect(
        tester
            .widget<Semantics>(find.bySemanticsLabel('扬声器'))
            .properties
            .toggled,
        isTrue,
      );
      await tester.tap(find.bySemanticsLabel('拨号盘'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('translation-dtmf-1')));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.tap(find.bySemanticsLabel('挂断'));
      await tester.pumpAndSettle();
      expect(find.textContaining('merchant 1 / hangup 1'), findsOneWidget);
      expect(find.textContaining('音频占用：已释放'), findsOneWidget);
      expect(find.textContaining('dtmf_digit'), findsOneWidget);
      expect(find.textContaining('speaker:true'), findsOneWidget);
      expect(
        find.textContaining('web_client_ready → merchant-call'),
        findsOneWidget,
      );
    });
  }
  testWidgets('cancel before room connect settles without merchant call', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.bySemanticsLabel('挂断'));
    await tester.pumpAndSettle();
    expect(find.textContaining('merchant 0 / hangup 1'), findsOneWidget);
    expect(find.textContaining('音频占用：已释放'), findsOneWidget);
  });
}
