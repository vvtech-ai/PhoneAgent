import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_precheck_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/pages/conversation_page.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/native_conversation_precheck_card.dart';
import 'package:phone_agent/features/settings/domain/network_availability.dart';
import 'package:phone_agent/features/settings/domain/network_availability_events.dart';

class _Network implements NetworkAvailabilitySource, NetworkAvailabilityEvents {
  final changes = StreamController<NetworkAvailability>.broadcast(sync: true);
  @override
  Future<NetworkAvailability> read() async => NetworkAvailability.available;
  @override
  Stream<NetworkAvailability> watch() => changes.stream;
}

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform shows original steps, keeps failure and resumes', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final network = _Network();
      final check = ConversationPrecheckController(network, network);
      addTearDown(() {
        check.dispose();
        network.changes.close();
      });
      var history = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: Scaffold(
            body: AnimatedBuilder(
              animation: check,
              builder: (_, __) => ConversationPage(
                precheck: check.presentation,
                precheckStatus: check.label,
                precheckBlocked: check.blocked,
                state: ConversationState(
                  entry: const ConversationEntry(sessionId: 'check'),
                  voiceMode: false,
                  messages: history
                      ? const [
                          ConversationMessage(
                            id: 'old',
                            role: MessageRole.user,
                            text: '已有任务内容',
                          ),
                        ]
                      : const [],
                ),
                modelName: '测试模型',
                onClose: () {},
                onToggle: () {},
                onSend: (_) => false,
                onChoose: (_, __) => false,
                onRetry: () {},
                onNotice: (_) {},
                onModels: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.text('正在初始化任务执行环境'), findsOneWidget);
      for (final title in ['网络连接', '大模型服务', '外呼通道']) {
        expect(find.text(title), findsOneWidget);
      }
      expect(find.byType(NativeConversationPrecheckCard), findsOneWidget);
      expect(
        tester
            .widget<NativeConversationPrecheckCard>(
              find.byType(NativeConversationPrecheckCard),
            )
            .inline,
        isFalse,
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('网络连接正常'), findsOneWidget);
      expect(find.text('正在连接大模型服务'), findsNWidgets(2));
      check.model(ready: false, blocked: true, error: '模型服务暂时不可用');
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('模型服务暂时不可用'), findsOneWidget);
      expect(find.text('任务执行环境检测通过'), findsNothing);
      history = true;
      check.model(ready: true, blocked: false, name: 'QwenOmniPlus');
      await tester.pump();
      expect(find.text('已有任务内容'), findsOneWidget);
      expect(
        tester
            .widget<NativeConversationPrecheckCard>(
              find.byType(NativeConversationPrecheckCard),
            )
            .inline,
        isTrue,
      );
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('外呼通道已就绪'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(NativeConversationPrecheckCard), findsNothing);
      network.changes.add(NetworkAvailability.unavailable);
      await tester.pump();
      expect(find.byType(NativeConversationPrecheckCard), findsOneWidget);
      expect(find.text('已有任务内容'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
