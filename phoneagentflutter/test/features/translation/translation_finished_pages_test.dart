import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/presentation/pages/translation_session_preview_page.dart';

void main() {
  Future<void> open(WidgetTester tester) async {
    await tester.ensureVisible(find.text('正常会话与字幕'));
    await tester.tap(find.text('正常会话与字幕'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('注入媒体就绪'));
    await tester.pumpAndSettle();
  }

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets(
      'finished returns to shared recent list at $width; no fake settlement',
      (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          const MaterialApp(home: TranslationSessionPreviewPage()),
        );
        await tester.pumpAndSettle();
        await open(tester);
        expect(find.textContaining('本次演练记录 1 条'), findsNothing);
        await tester.tap(find.text('注入对方接通'));
        await tester.pump();
        await tester.tap(find.text('注入对方挂断'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('MOCK · 本次演练记录 1 条'));
        expect(find.text('合成翻译联系人'), findsOneWidget);
        expect(find.text('通话结算'), findsNothing);
        await tester.ensureVisible(find.text('合成翻译联系人'));
        await tester.tap(find.text('合成翻译联系人'));
        await tester.pump();
        expect(
          find.textContaining('+12025550101 · US · zh，未发起呼叫'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('failed local save retries without another create or hangup', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: TranslationSessionPreviewPage()),
    );
    await tester.pumpAndSettle();
    final fail = find.byKey(const Key('translation-record-fail-write'));
    await tester.ensureVisible(fail);
    await tester.tap(fail);
    await tester.pump();
    await open(tester);
    await tester.tap(find.text('注入对方挂断'));
    await tester.pumpAndSettle();
    final retry = find.byKey(const Key('translation-record-retry'));
    await tester.ensureVisible(retry);
    expect(find.text('MOCK · 本次演练记录 0 条'), findsOneWidget);
    await tester.ensureVisible(fail);
    await tester.tap(fail);
    await tester.pump();
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(retry, findsNothing);
    expect(find.text('MOCK · 本次演练记录 1 条'), findsOneWidget);
    expect(
      find.textContaining('create 1 / merchant 1 / hangup 1'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
