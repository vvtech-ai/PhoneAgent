import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/calls/data/preview_call_flow.dart';
import 'package:phone_agent/features/calls/presentation/pages/call_session_page.dart';
import 'package:phone_agent/features/calls/presentation/pages/conversation_call_host.dart';
import 'conversation_call_flow_test.dart' show conversation, launch;

void main() {
  testWidgets('iOS edge swipe cannot leave an active single-call route', (
    tester,
  ) async {
    final ports = PreviewCallFlow(CallFlowScenario.single);
    final controller = conversation(ports);
    addTearDown(controller.dispose);
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: const Scaffold(body: Text('根页面')),
      ),
    );
    navigator.currentState!.push<void>(
      CupertinoPageRoute(
        builder: (_) => Scaffold(
          body: ConversationCallHost(
            controller: controller.calls,
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
    await tester.dragFrom(const Offset(1, 300), const Offset(350, 0));
    await tester.pumpAndSettle();
    expect(find.byType(CallSessionPage), findsOneWidget);
    expect(find.text('原任务会话'), findsNothing);
    expect(controller.calls!.activeRequest, same(request));
    expect(controller.isOpen, isTrue);
    await tester.pump(const Duration(seconds: 2));
    expect(ports.polls, greaterThan(polls));
    expect(ports.hangups, 0);
    controller.close();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('system back keeps active call visible and never hangs up', (
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
    expect(find.byType(CallSessionPage), findsOneWidget);
    final request = controller.calls!.activeRequest;
    final polls = ports.polls;
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(CallSessionPage), findsOneWidget);
    expect(find.text('原任务会话'), findsNothing);
    expect(controller.calls!.activeRequest, same(request));
    expect(controller.isOpen, isTrue);
    expect(ports.hangups, 0);
    await tester.pump(const Duration(seconds: 2));
    expect(ports.polls, greaterThan(polls));
    expect(find.byType(CallSessionPage), findsOneWidget);
    expect(ports.hangups, 0);
    controller.close();
    await tester.pumpWidget(const SizedBox());
  });
}
