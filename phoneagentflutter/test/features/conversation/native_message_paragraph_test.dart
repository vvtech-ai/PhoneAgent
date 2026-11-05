import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/native_message_paragraph.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('phone_agent/native_paragraph');
  const style = TextStyle(fontSize: 14, height: 22 / 14, color: Colors.white);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  setUp(() => calls.clear());
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  Future<void> mount(
    WidgetTester tester, {
    String text = '合成消息',
    double width = 250,
    double scale = 1,
    bool native = true,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: SizedBox(
            width: width,
            child: Align(
              alignment: Alignment.topLeft,
              child: NativeMessageParagraph(
                text: text,
                style: style,
                useNative: native,
                nativeViewBuilder: (args) => Text('NATIVE:${args['text']}'),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('scaled layout uses measured native size and plain parameters', (
    tester,
  ) async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return {'width': 120.0, 'height': 88.0};
    });
    await mount(tester, scale: 2);
    await tester.pumpAndSettle();
    expect(find.text('NATIVE:合成消息'), findsOneWidget);
    expect(find.byType(SelectableText), findsNothing);
    final args = calls.single.arguments as Map;
    expect(args, {
      'text': '合成消息',
      'maxWidth': 250.0,
      'fontSize': 28.0,
      'lineHeight': 44.0,
      'color': Colors.white.toARGB32(),
      'direction': 'ltr',
    });
    final box = find
        .ancestor(of: find.text('NATIVE:合成消息'), matching: find.byType(SizedBox))
        .first;
    expect(tester.getSize(box), const Size(120, 88));
    await tester.pump();
    expect(calls, hasLength(1));
  });

  testWidgets(
    'late measurements cannot replace current text or disposed state',
    (tester) async {
      final replies = <Completer<Map<String, Object?>>>[];
      messenger.setMockMethodCallHandler(channel, (call) {
        calls.add(call);
        final reply = Completer<Map<String, Object?>>();
        replies.add(reply);
        return reply.future;
      });
      await mount(tester, text: '旧合成消息');
      await tester.pump();
      await mount(tester, text: '新合成消息', width: 200);
      await tester.pump();
      replies[0].complete({'width': 150.0, 'height': 22.0});
      await tester.pumpAndSettle();
      expect(find.text('NATIVE:旧合成消息'), findsNothing);
      replies[1].complete({'width': 100.0, 'height': 44.0});
      await tester.pumpAndSettle();
      expect(find.text('NATIVE:新合成消息'), findsOneWidget);
      await mount(tester, text: '晚到合成消息');
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      replies[2].complete({'width': 100.0, 'height': 22.0});
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  for (final response in ['missing', 'failed', 'invalid']) {
    testWidgets('$response retains Flutter without infinite retry', (
      tester,
    ) async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (response == 'missing') return null;
        if (response == 'failed') throw PlatformException(code: 'unavailable');
        return {'width': 300.0, 'height': double.nan};
      });
      await mount(tester);
      await tester.pumpAndSettle();
      expect(find.byType(SelectableText), findsOneWidget);
      expect(find.text('NATIVE:合成消息'), findsNothing);
      await tester.pump();
      expect(calls, hasLength(1));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'pending text keeps native rendering and failed update shows current fallback',
    (tester) async {
      final replies = <Completer<Map<String, Object?>>>[];
      messenger.setMockMethodCallHandler(channel, (call) {
        calls.add(call);
        final reply = Completer<Map<String, Object?>>();
        replies.add(reply);
        return reply.future;
      });
      await mount(tester, text: '合成第一句');
      replies[0].complete({'width': 100.0, 'height': 22.0});
      await tester.pumpAndSettle();
      await mount(tester, text: '合成第二句');
      await tester.pump();
      expect(find.text('NATIVE:合成第一句'), findsOneWidget);
      expect(find.byType(SelectableText), findsNothing);
      replies[1].complete({'width': 120.0, 'height': 44.0});
      await tester.pumpAndSettle();
      expect(find.text('NATIVE:合成第二句'), findsOneWidget);
      await mount(tester, text: '合成失败句');
      await tester.pump();
      replies[2].completeError(PlatformException(code: 'unavailable'));
      await tester.pumpAndSettle();
      expect(find.text('合成失败句'), findsOneWidget);
      expect(find.byType(SelectableText), findsOneWidget);
      expect(find.text('NATIVE:合成第二句'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Flutter platform bypasses channel and pending native callbacks',
    (tester) async {
      final pending = Completer<Map<String, Object?>>();
      messenger.setMockMethodCallHandler(channel, (call) {
        calls.add(call);
        return pending.future;
      });
      await mount(tester);
      await tester.pump();
      await mount(tester, native: false);
      pending.complete({'width': 100.0, 'height': 22.0});
      await tester.pumpAndSettle();
      expect(find.byType(SelectableText), findsOneWidget);
      expect(find.text('NATIVE:合成消息'), findsNothing);
      expect(calls, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );
}
