import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/presentation/pages/voice_input_preview_page.dart';

void main() {
  Future<void> mount(WidgetTester tester, {double width = 390}) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        // Business transitions are checked here; wave frames have their own suite.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: const VoiceInputPreviewPage(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('toggle-text')));
    await tester.pumpAndSettle();
  }

  Future<void> scenario(WidgetTester tester, String label) async {
    await tester.tap(find.text('模拟异常'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  Future<void> send(WidgetTester tester, String text) async {
    await tester.enterText(
      find.byKey(const ValueKey('conversation-input')),
      text,
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('send-text')));
    await tester.pumpAndSettle();
  }

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('same page revises failed sentence once at width $width', (
      tester,
    ) async {
      await mount(tester, width: width);
      await scenario(tester, '下次提交断网：尚未完成');
      await send(tester, '明天下午');
      expect(find.textContaining('请求 1 次'), findsOneWidget);
      expect(find.textContaining('已保留本轮内容'), findsOneWidget);
      await send(tester, '下午开会');
      expect(find.textContaining('请求 2 次'), findsOneWidget);
      expect(find.text('明天下午'), findsNothing);
      expect(find.text('明天下午开会'), findsOneWidget);
      expect(find.textContaining('MOCK：已收到输入'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'committed original repeated input restores without another request',
    (tester) async {
      await mount(tester);
      await scenario(tester, '下次提交断网：后台已完成');
      await send(tester, '明天下午');
      await send(tester, '明天下午');
      expect(find.textContaining('请求 1 次'), findsOneWidget);
      expect(find.text('明天下午'), findsOneWidget);
      expect(find.textContaining('MOCK：已收到输入'), findsOneWidget);
    },
  );
  testWidgets(
    'history failure keeps request count until explicit retry after recovery',
    (tester) async {
      await mount(tester);
      await scenario(tester, '下次断网且历史同步失败');
      await send(tester, '明天下午');
      await send(tester, '下午开会');
      expect(find.textContaining('请求 1 次'), findsOneWidget);
      expect(find.textContaining('断网前内容已保留'), findsOneWidget);
      await scenario(tester, '恢复正常连接');
      expect(find.textContaining('请求 1 次'), findsOneWidget);
      await send(tester, '下午开会');
      expect(find.textContaining('请求 2 次'), findsOneWidget);
      expect(find.text('明天下午开会'), findsOneWidget);
    },
  );
}
