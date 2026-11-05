import '../../support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/conversation_providers.dart';
import 'package:phone_agent/app/conversation_voice_providers.dart';
import 'package:phone_agent/features/attachments/data/preview_ocr_session.dart';
import 'package:phone_agent/features/attachments/presentation/widgets/ocr_attachment_card.dart';
import 'package:phone_agent/features/call_models/domain/call_models.dart';
import 'package:phone_agent/features/call_models/presentation/controller/call_model_controller.dart';
import 'package:phone_agent/features/conversation/presentation/pages/conversation_route.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'ocr_conversation_flow_test.dart' show createConversation;
import '../../../tool/previews/shell_task_parity_ports.dart';

void main() {
  testWidgets(
    'production route album, rendered image, text context and close share one session',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final ports = PreviewOcrSession();
      final controller = createConversation(ports);
      const entry = ConversationEntry(sessionId: PreviewOcrSession.sessionId);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...shellTaskParityOverrides(),
            currentAccountIdProvider.overrideWithValue('synthetic-ocr'),
            voiceInputAvailableProvider.overrideWithValue(false),
            voiceInputFactoryProvider.overrideWithValue(
              (_) => throw StateError('OCR test must not open audio'),
            ),
            conversationControllerProvider(
              entry,
            ).overrideWith((ref) => controller),
            callModelControllerProvider.overrideWith(
              (ref) => CallModelController(_Models())..load(),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const ConversationRoute(entry: entry),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpUntilUiSettled();
      await tester.tap(find.bySemanticsLabel('添加图片'));
      await tester.pumpUntilUiSettled();
      await tester.tap(find.text('相册'));
      await tester.pumpUntilUiSettled();
      // Decorative thinking can settle while the OCR ports still await timers.
      for (
        var tick = 0;
        tick < 20 && controller.attachments!.snapshot.busy;
        tick++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpUntilUiSettled();
      expect(find.byType(OcrAttachmentCard), findsOneWidget);
      expect(
        controller.attachments!.snapshot.processing.successful,
        hasLength(1),
        reason: '识别与云端提交完成后才能检查成功卡片内容',
      );
      expect(find.text('已识别图片文字'), findsOneWidget);
      expect(find.text('图片暂不可用'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('toggle-text')));
      await tester.pumpUntilUiSettled();
      await tester.enterText(find.byType(TextField), '合成文字，不要拨号');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('send-text')));
      await tester.pumpUntilUiSettled();
      expect(
        ports.commands.single.userContext!['ocrAttachments'],
        hasLength(1),
      );
      await tester.tap(find.byKey(const ValueKey('close-conversation')));
      await tester.pumpUntilUiSettled();
      expect(find.text('open'), findsOneWidget);
      expect(controller.isOpen, false);
      expect(tester.takeException(), isNull);
    },
  );
}

class _Models implements CallModelRepository {
  @override
  Future<CallModelCatalog> load() async => const CallModelCatalog('mock', [
    CallModel(
      id: 'mock',
      name: '合成测试模型',
      description: '',
      available: true,
      active: true,
    ),
  ]);
  @override
  Future<CallModelCatalog> select(String provider) => load();
  @override
  Future<CallVoiceCatalog> loadVoices(String provider) async =>
      const CallVoiceCatalog('', '', []);
  @override
  Future<CallVoiceCatalog> selectVoice(String provider, String voice) =>
      loadVoices(provider);
}
