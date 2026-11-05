import 'package:phone_agent/features/translation/presentation/controller/translation_session_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/presentation/pages/translation_access_preview_page.dart';
import 'package:phone_agent/features/translation/presentation/pages/translation_session_route.dart';

void main() {
  Future<void> press(WidgetTester tester, Finder target) async {
    await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(target);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> open(WidgetTester tester, {bool overseas = true}) async {
    await tester.pumpWidget(
      const MaterialApp(home: TranslationAccessPreviewPage()),
    );
    await tester.pumpAndSettle();
    if (overseas) await press(tester, find.text('模拟 US'));
    await press(tester, find.text('配置到通话流程（MOCK）'));
    expect(
      tester
          .widget<SwitchListTile>(
            find.widgetWithText(SwitchListTile, '配置到通话流程（MOCK）'),
          )
          .value,
      true,
    );
    await press(tester, find.text('原音播放（MOCK）'));
    await press(tester, find.text('进入共享翻译拨号页'));
  }

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('dial preferences to same session and back at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, width == 320 ? 568 : 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await open(tester);
      await press(tester, find.byKey(const Key('translation-presets-open')));
      await press(tester, find.byKey(const Key('translation-peer')));
      await press(tester, find.byKey(const Key('language-fr')));
      await press(tester, find.byKey(const Key('translation-presets-close')));
      await tester.ensureVisible(find.byKey(const Key('dial-call')));
      final call = tester
          .widget<InkWell>(find.byKey(const Key('dial-call')))
          .onTap!;
      call();
      call();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.byType(TranslationSessionRoute),
        findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((e) => e.data)
            .join(' | '),
      );
      final controller =
          tester
                  .widget<TranslationSessionRoute>(
                    find.byType(TranslationSessionRoute),
                  )
                  .createController()
              as TranslationSessionController;
      expect(controller.request.phone, '+12025550123');
      expect(controller.request.merchantLanguage, 'fr');
      expect(controller.request.originalAudioEnabled, true);
      await press(tester, find.text('注入媒体就绪'));
      expect(find.text('正在振铃'), findsOneWidget);
      await press(tester, find.text('注入对方接通'));
      await press(tester, find.text('注入双语字幕'));
      await press(tester, find.bySemanticsLabel('挂断'));
      await tester.pumpAndSettle();
      expect(find.byType(TranslationSessionRoute), findsNothing);
      expect(find.textContaining('法语 对方'), findsOneWidget);
      expect(find.text('202 555 0123'), findsOneWidget);
      expect(find.text('通话已结束'), findsNothing);
      expect(find.byKey(const Key('dial-message')), findsNothing);
      await press(tester, find.byKey(const Key('dial-close')));
      expect(find.textContaining('流程记录 1 条'), findsOneWidget);
      expect(find.textContaining('zh→fr'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'domestic entry without safe model configuration never creates overseas session',
    (tester) async {
      await open(tester, overseas: false);
      await press(tester, find.byKey(const Key('dial-call')));
      expect(find.text('跨境通话质量提示'), findsOneWidget);
      await press(tester, find.byKey(const Key('cross-border-continue')));
      expect(find.byType(TranslationSessionRoute), findsNothing);
      expect(find.text('通话未接通，请稍后重试'), findsOneWidget);
      expect(find.byKey(const ValueKey('nativeNoticeSurface')), findsOneWidget);
      expect(find.byKey(const Key('dial-message')), findsNothing);
      await press(tester, find.byKey(const Key('dial-close')));
      expect(find.textContaining('流程记录 0 条'), findsOneWidget);
    },
  );
  testWidgets(
    'archive failure after return retries only history synchronization',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: TranslationAccessPreviewPage()),
      );
      await tester.pumpAndSettle();
      await press(tester, find.text('模拟 US'));
      await press(tester, find.text('配置到通话流程（MOCK）'));
      await press(tester, find.text('归档接口失败（MOCK）'));
      await press(tester, find.text('进入共享翻译拨号页'));
      await press(tester, find.byKey(const Key('dial-call')));
      await press(tester, find.text('注入媒体就绪'));
      await press(tester, find.text('注入对方接通'));
      await press(tester, find.bySemanticsLabel('挂断'));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      await press(tester, find.byKey(const Key('dial-close')));
      expect(find.textContaining('服务端归档 0 条 / 请求 1 次'), findsOneWidget);
      expect(find.text('翻译历史同步未完成，点击重试'), findsOneWidget);
      await press(tester, find.text('归档接口失败（MOCK）'));
      await press(tester, find.byKey(const Key('translation-archive-retry')));
      expect(find.textContaining('服务端归档 1 条 / 请求 2 次'), findsOneWidget);
      expect(find.textContaining('流程记录 1 条'), findsOneWidget);
      expect(find.byType(TranslationSessionRoute), findsNothing);
    },
  );
  testWidgets(
    'cancel presets creates no session; next attempt may enter and cancel preparation',
    (tester) async {
      await open(tester);
      await press(tester, find.byKey(const Key('translation-presets-open')));
      await press(tester, find.byKey(const Key('translation-prompt')));
      await press(tester, find.byKey(const Key('translation-presets-close')));
      await press(tester, find.byKey(const Key('dial-call')));
      await press(tester, find.byKey(const Key('translation-presets-close')));
      expect(find.byType(TranslationSessionRoute), findsNothing);
      await press(tester, find.byKey(const Key('dial-call')));
      await press(tester, find.widgetWithText(FilledButton, '实时翻译呼叫'));
      expect(find.byType(TranslationSessionRoute), findsOneWidget);
      await press(tester, find.bySemanticsLabel('挂断'));
      await tester.pumpAndSettle();
      expect(find.byType(TranslationSessionRoute), findsNothing);
      expect(find.text('202 555 0123'), findsOneWidget);
    },
  );
}
