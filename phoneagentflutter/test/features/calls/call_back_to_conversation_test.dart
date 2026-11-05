import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/calls/data/preview_call_flow.dart';
import 'package:phone_agent/features/calls/data/preview_call_monitor.dart';
import 'package:phone_agent/features/calls/presentation/pages/call_session_page.dart';
import 'package:phone_agent/features/calls/presentation/pages/conversation_call_host.dart';
import 'package:phone_agent/features/calls/presentation/widgets/native_call_audio_source_sheet.dart';
import 'conversation_call_flow_test.dart' show conversation, launch;

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform back keeps call route, monitor and observer alive', (
      tester,
    ) async {
      final ports = PreviewCallFlow(CallFlowScenario.single);
      final controller = conversation(ports);
      final media = PreviewCallMonitor();
      final createMonitor = media.create;
      final navigator = GlobalKey<NavigatorState>();
      addTearDown(controller.dispose);
      addTearDown(media.dispose);
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          theme: ThemeData(platform: platform),
          home: const Scaffold(body: Text('父路由')),
        ),
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            body: ConversationCallHost(
              controller: controller.calls,
              createMonitor: createMonitor,
              modelName: '合成模型',
              child: const Text('原任务会话'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await launch(tester, controller);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(CallSessionPage), findsOneWidget);
      final request = controller.calls!.activeRequest;
      final polls = ports.polls;
      await tester.tap(find.bySemanticsLabel('开始监听'));
      await tester.pumpAndSettle();
      media.pcm();
      await tester.pump();
      final output = media.output!;
      final socket = media.socket!;
      final tickets = media.tickets;
      expect(output.stopped, isFalse);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(CallSessionPage), findsOneWidget);
      expect(find.text('原任务会话'), findsNothing);
      expect(navigator.currentState!.canPop(), isTrue);
      // The platform gesture must also leave the call surface and route intact.
      if (platform == TargetPlatform.android) {
        Future<void> backGesture(String method, [Object? arguments]) async {
          await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
            'flutter/backgesture',
            const StandardMethodCodec().encodeMethodCall(
              MethodCall(method, arguments),
            ),
            (_) {},
          );
        }

        await backGesture('startBackGesture', <String, Object>{
          'touchOffset': <double>[0, 200],
          'progress': 0.0,
          'swipeEdge': 0,
        });
        await backGesture('commitBackGesture');
      } else {
        await tester.dragFrom(const Offset(1, 200), const Offset(500, 0));
      }
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(CallSessionPage), findsOneWidget);
      expect(controller.calls!.activeRequest, same(request));
      expect(controller.isOpen, isTrue);
      expect(ports.hangups, 0);
      await tester.pump(const Duration(seconds: 2));
      expect(ports.polls, greaterThan(polls));
      expect(find.byType(CallSessionPage), findsOneWidget);
      expect(ports.hangups, 0);
      expect(output.stopped, isFalse);
      expect(socket.closed, isFalse);
      expect(media.tickets, tickets);
      final received = media.receivedBytes;
      media.pcm();
      await tester.pump();
      expect(media.receivedBytes, greaterThan(received));
      await tester.tap(find.bySemanticsLabel('音源，听筒'));
      await tester.pumpAndSettle();
      expect(find.byType(NativeCallAudioSourceSheet), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(NativeCallAudioSourceSheet), findsNothing);
      expect(find.byType(CallSessionPage), findsOneWidget);
      expect(output.stopped, isFalse);
      expect(socket.closed, isFalse);
      expect(ports.hangups, 0);
      ports.ended = true;
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(find.byType(CallSessionPage), findsNothing);
      expect(find.text('原任务会话'), findsOneWidget);
      expect(output.stopped, isTrue);
      expect(ports.hangups, 0);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('父路由'), findsOneWidget);
      expect(find.text('原任务会话'), findsNothing);
      controller.close();
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('explicit successful hangup returns to conversation once', (
    tester,
  ) async {
    final ports = PreviewCallFlow(CallFlowScenario.single);
    final controller = conversation(ports);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConversationCallHost(
            controller: controller.calls,
            modelName: '合成模型',
            child: const Text('原任务会话'),
          ),
        ),
      ),
    );
    await launch(tester, controller);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const ValueKey('call-挂断')));
    await tester.pump();
    expect(ports.hangups, 1);
    expect(find.byType(CallSessionPage), findsNothing);
    expect(find.text('原任务会话'), findsOneWidget);
    expect(controller.isOpen, isTrue);
    controller.close();
    await tester.pumpWidget(const SizedBox());
  });
}
