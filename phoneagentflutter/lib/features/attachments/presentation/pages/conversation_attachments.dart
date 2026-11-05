import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/attachment_tokens.dart';
import '../../../conversation/presentation/controller/conversation_controller.dart';
import '../widgets/attachment_menu.dart';

Future<void> openConversationAttachments(
  BuildContext context,
  WidgetRef ref,
  ConversationController conversation, {
  required bool canSend,
  required Future<void> Function() openDocuments,
}) async {
  if (!canSend) {
    conversation.showNotice('任务处理中，请稍后添加');
    return;
  }
  FocusScope.of(context).unfocus();
  final choice = await showModalBottomSheet<AttachmentChoice>(
    context: context,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 430),
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x3D0F172A),
    builder: (sheet) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AttachmentTokens.radius),
          ),
        ),
        child: AttachmentMenu(
          onChoose: (choice) => Navigator.pop(sheet, choice),
          onClose: () => Navigator.pop(sheet),
        ),
      ),
    ),
  );
  if (!context.mounted || choice == null) return;
  if (choice == AttachmentChoice.album) {
    final ocr = conversation.attachments;
    if (!conversation.isOpen || ocr == null) return;
    if (!conversation.canAttach) {
      conversation.showNotice('任务处理中，请稍后添加');
      return;
    }
    if (ocr.snapshot.busy) {
      conversation.showNotice('图片处理中，请稍后添加');
      return;
    }
    await conversation.speech?.pause();
    if (!context.mounted || !conversation.isOpen || !conversation.canAttach) {
      return;
    }
    await ocr.pick(
      conversation.ocrBoundary.sourceAnchor,
      currentAnchor: () => conversation.ocrBoundary.sourceAnchor,
    );
    if (conversation.isOpen && ocr.snapshot.notice.isNotEmpty) {
      conversation.showNotice(ocr.snapshot.notice);
    }
    return;
  }
  if (!conversation.isOpen || !conversation.canAttach) return;
  await openDocuments();
}
