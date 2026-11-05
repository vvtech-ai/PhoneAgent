import 'support/pump_ui_transitions.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/conversation_providers.dart';
import 'package:phone_agent/app/phone_agent_app.dart';
import 'package:phone_agent/features/attachments/data/preview_documents.dart';
import 'package:phone_agent/features/attachments/data/preview_ocr.dart';
import 'package:phone_agent/features/attachments/presentation/widgets/ocr_attachment_card.dart';
import 'package:phone_agent/features/attachments/presentation/widgets/native_document_card.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/conversation/presentation/pages/conversation_route.dart';
import '../tool/previews/auth_scenario.dart';
import '../tool/previews/migration_workbench.dart';
import '../tool/previews/shell_attachment_ports.dart';
import '../tool/previews/shell_conversation_ports.dart';
import '../tool/previews/workbench_catalog.dart';

void main() {
  for (final width in [320.0, 430.0]) {
    testWidgets('formal attachments, history and session isolation $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MigrationWorkbench(
          scenes: [workbenchScenes.singleWhere((s) => s.id == 'app')],
        ),
      );
      Future<void> settle() async {
        await tester.pumpUntilUiSettled();
        expect(tester.takeException(), isNull);
      }

      Future<void> tap(Finder finder) async {
        await settle();
        if (finder.evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            finder,
            220,
            scrollable: find.byType(Scrollable).last,
          );
        }
        await Scrollable.ensureVisible(tester.element(finder), alignment: .35);
        await settle();
        await tester.tap(finder);
        await settle();
      }

      Future<void> key(String id) => tap(find.byKey(ValueKey(id)));
      Future<void> text(String value) => tap(find.text(value));
      Future<void> attachments(String choice) async {
        await tap(find.bySemanticsLabel('添加图片'));
        await text(choice);
        if (choice == '文档') {
          await tester.pump(const Duration(milliseconds: 350));
          await tester.pump(const Duration(milliseconds: 350));
          await settle();
        }
      }

      await settle();
      await key('scene-app');
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PhoneAgentApp)),
      );
      final ports = container.read(shellAttachmentPortsProvider);
      final agent = container.read(shellConversationPortsProvider);
      final auth = container.read(sessionStoreProvider) as AuthScenario;
      await key('skill-restaurant_booking');
      final entry = tester
          .widget<ConversationRoute>(find.byType(ConversationRoute))
          .entry;
      final controller = container.read(
        conversationControllerProvider(entry).notifier,
      );

      ports.documentScenario = DocumentPreviewScenario.cancelled;
      await attachments('文档');
      expect(find.text('导入文档'), findsNothing);
      expect(agent.commands, isEmpty);
      ports.documentScenario = DocumentPreviewScenario.failure;
      await attachments('文档');
      expect(find.text('MOCK：第二个文件解析失败'), findsOneWidget);
      expect(agent.commands, isEmpty, reason: '整批失败不能提交部分文档');
      ports.documentScenario = DocumentPreviewScenario.success;
      await attachments('文档');
      await tester.pump(const Duration(milliseconds: 500));
      await settle();
      expect(agent.commands, hasLength(1));
      expect(agent.commands.single.inputKind, 'document');
      expect(
        jsonDecode(agent.commands.single.message!)['documents'],
        hasLength(2),
      );
      expect(find.textContaining('user_document_batch.v1'), findsNothing);
      await key('close-conversation');
      await key('tab-2');
      expect(find.text('AI 通话 · MOCK · 文档资料'), findsOneWidget);
      await key('conversation:${entry.sessionId}');
      expect(find.byType(NativeDocumentCard), findsOneWidget);
      expect(
        tester
            .widget<NativeDocumentCard>(find.byType(NativeDocumentCard))
            .files,
        hasLength(2),
      );
      expect(agent.commands, hasLength(1));
      await tap(find.textContaining('合成餐厅甲'));
      await tester.pump(const Duration(milliseconds: 500));
      await settle();

      ports.imageScenario = OcrPreviewScenario.meeting;
      await attachments('相册');
      final imageEntry = tester
          .widget<ConversationRoute>(find.byType(ConversationRoute))
          .entry;
      final imageOwner = container.read(
        conversationControllerProvider(imageEntry).notifier,
      );
      for (
        var tick = 0;
        tick < 20 && imageOwner.attachments!.snapshot.busy;
        tick++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await settle();
      expect(
        imageOwner.attachments!.snapshot.processing.successful,
        hasLength(1),
      );
      expect(ports.uploads, 1);
      expect(agent.commands, hasLength(2), reason: '仅选图不能自动向Agent发话');
      expect(find.text('已识别图片文字'), findsOneWidget);
      await text('展开');
      expect(find.text('收起'), findsOneWidget);
      await text('收起');
      final restoredEntry = tester
          .widget<ConversationRoute>(find.byType(ConversationRoute))
          .entry;
      final before = container.read(
        conversationControllerProvider(restoredEntry).notifier,
      );
      final image = before.attachments!.snapshot.processing.attachments.single;
      expect(image.anchor, greaterThan(0));
      expect(before.attachments!.userContext?['ocrAttachments'], hasLength(1));
      await key('toggle-text');
      await tester.enterText(
        find.byKey(const ValueKey('conversation-input')),
        '整理图片，不要拨号',
      );
      await key('send-text');
      await tester.pump(const Duration(milliseconds: 500));
      await settle();
      expect(
        agent.commands.length,
        3,
        reason: container
            .read(conversationControllerProvider(restoredEntry))
            .notice,
      );
      expect(agent.commands.last.userContext!['ocrAttachments'], hasLength(1));
      await key('close-conversation');
      final count = agent.commands.length;
      await key('conversation:${entry.sessionId}');
      expect(ports.uploads, 1, reason: '恢复不重复上传');
      expect(ports.imageReads, 1);
      expect(agent.commands.length, count, reason: '恢复不重发命令');
      expect(find.byType(OcrAttachmentCard), findsOneWidget);
      final card = tester.widget<OcrAttachmentCard>(
        find.byType(OcrAttachmentCard),
      );
      expect(card.attachment.id, image.id);
      expect(card.attachment.anchor, image.anchor);
      await tester.scrollUntilVisible(
        find.byType(NativeDocumentCard),
        250,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('conversation-timeline')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.byType(NativeDocumentCard), findsOneWidget);
      expect(
        tester
            .widget<NativeDocumentCard>(find.byType(NativeDocumentCard))
            .files,
        hasLength(2),
      );
      await key('toggle-text');
      await tester.enterText(
        find.byKey(const ValueKey('conversation-input')),
        '恢复后继续',
      );
      await key('send-text');
      await tester.pump(const Duration(milliseconds: 500));
      await settle();
      expect(agent.commands.last.userContext!['ocrAttachments'], hasLength(1));
      await key('close-conversation');
      await key('tab-0');
      await key('skill-restaurant_booking');
      expect(find.byType(OcrAttachmentCard), findsNothing);
      await key('toggle-text');
      await tester.enterText(
        find.byKey(const ValueKey('conversation-input')),
        '另一个会话',
      );
      await key('send-text');
      await tester.pump(const Duration(milliseconds: 500));
      await settle();
      expect(agent.commands.last.userContext?['ocrAttachments'], isNull);
      expect(agent.commands.last.sessionId, isNot(entry.sessionId));
      expect(controller.isOpen, false);
      await key('close-conversation');
      await key('tab-3');
      await key('settings-logout');
      await text('退出');
      await tester.enterText(
        find.byKey(const ValueKey('loginPhone')),
        '13800000000',
      );
      await tester.enterText(find.byKey(const ValueKey('loginCode')), '123456');
      await key('loginBtn');
      expect(container.read(shellAttachmentPortsProvider), isNot(same(ports)));
      expect(container.read(shellAttachmentPortsProvider).uploads, 0);
      expect(auth.sends, 0);
      await expectLater(ports.pickImage(), throwsStateError);
      await key('workbench-home');
      await tester.pumpWidget(const SizedBox());
      await settle();
    });
  }
}
