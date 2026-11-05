import 'package:phone_agent/core/design/native_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/presentation/pages/translation_session_preview_page.dart';

void main() {
  tearDown(dismissNativeNotice);
  Future<void> open(WidgetTester tester, String scenario) async {
    await tester.pumpWidget(
      const MaterialApp(home: TranslationSessionPreviewPage()),
    );
    await tester.tap(find.text(scenario));
    await tester.pump();
    // Preparation intentionally has an indeterminate loader and a ready gate.
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> ready(WidgetTester tester) async {
    await tester.tap(find.text('注入媒体就绪'));
    await tester.pumpAndSettle();
    expect(find.text('正在振铃'), findsOneWidget);
    expect(find.text('实时翻译 · 已接通'), findsNothing);
  }

  Future<void> transientNotice(WidgetTester tester, String message) async {
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('nativeNoticeSurface')), findsOneWidget);
    expect(find.text(message), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('nativeNoticeSurface')), findsNothing);
    expect(find.textContaining(message), findsNothing);
  }

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets(
      'shared protocol route $width, controls, transcript and remote terminal',
      (tester) async {
        tester.view.physicalSize = Size(width, width == 320 ? 568 : 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await open(tester, '正常会话与字幕');
        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(find.bySemanticsLabel('挂断'), findsOneWidget);
        await ready(tester);
        await tester.tap(find.text('注入对方接通'));
        await tester.pump();
        expect(find.text('实时翻译 · 已接通'), findsOneWidget);
        await tester.tap(find.text('注入双语字幕'));
        await tester.pump();
        expect(find.text('我明白了。'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('静音'));
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('扬声器'));
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('拨号盘'));
        await tester.pump();
        await tester.ensureVisible(find.byKey(const Key('translation-dtmf-1')));
        await tester.tap(find.byKey(const Key('translation-dtmf-1')));
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('注入对方挂断'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('create 1 / merchant 1 / hangup 1'),
          findsOneWidget,
        );
        expect(find.textContaining('mute:true'), findsOneWidget);
        expect(find.textContaining('speaker:true'), findsOneWidget);
        expect(find.textContaining('dtmf:1'), findsOneWidget);
        expect(find.text('通话结算'), findsNothing);
      },
    );
  }
  testWidgets('preflight cancellation returns with no merchant request', (
    tester,
  ) async {
    await open(tester, '正常会话与字幕');
    await tester.tap(find.bySemanticsLabel('挂断'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('create 1 / merchant 0 / hangup 1'),
      findsOneWidget,
    );
  });
  testWidgets(
    'AppAudio fallback is visible and does not record unsupported DTMF',
    (tester) async {
      await open(tester, 'LiveKit失败后AppAudio回退');
      await ready(tester);
      await tester.tap(find.bySemanticsLabel('拨号盘'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('translation-dtmf-1')));
      await transientNotice(tester, '当前媒体通道不支持发送按键');
      expect(find.bySemanticsLabel('挂断'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('挂断'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('close:liveKit → connect:websocket'),
        findsOneWidget,
      );
      expect(find.textContaining('dtmf:1'), findsNothing);
    },
  );
  testWidgets(
    'control failure stays in call; terminal uncertainty returns as failure',
    (tester) async {
      await open(tester, '媒体按钮失败');
      await ready(tester);
      await tester.tap(find.bySemanticsLabel('静音'));
      await transientNotice(tester, '操作未成功，原状态未改变，请重试');
      expect(find.bySemanticsLabel('挂断'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('挂断'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('结束状态待确认'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await ready(tester);
      await tester.tap(find.bySemanticsLabel('挂断'));
      await transientNotice(tester, '通话未接通，请稍后重试');
      expect(
        find.textContaining('create 1 / merchant 1 / hangup 1'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'create failure and disconnect auto return, never domestic settlement',
    (tester) async {
      await open(tester, '创建失败');
      await tester.pumpAndSettle();
      expect(
        find.textContaining('create 1 / merchant 0 / hangup 0'),
        findsOneWidget,
      );
      await transientNotice(tester, '通话未接通，请稍后重试');
      await tester.tap(find.text('正常会话与字幕'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await ready(tester);
      await tester.tap(find.text('注入断线'));
      await transientNotice(tester, '网络连接异常，请检查网络后重试');
      expect(find.text('通话结算'), findsNothing);
    },
  );
}
