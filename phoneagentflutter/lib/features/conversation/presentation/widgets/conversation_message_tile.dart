import 'package:flutter/material.dart';
import '../../../calls/presentation/widgets/call_outcome_scope.dart';
import 'native_conversation_text_bubble.dart';
import '../../../attachments/presentation/widgets/native_document_card.dart';
import '../../domain/artifacts/task_artifact.dart';
import '../../domain/conversation_messages.dart';
import '../../domain/receipts/native_call_receipt_presentation.dart';
import '../../domain/conversation_tool_card.dart';
import 'call_confirmation_card.dart';
import 'batch_confirmation_card.dart';
import 'receipts/call_receipt_card.dart';
import 'receipts/batch_receipt_card.dart';
import 'conversation_options_card.dart';
import 'task_artifact_card.dart';
import 'native_thinking_card.dart';

/// Effective native message styles shared by mobile/Web.
/// Runtime comparison remains an acceptance gate.
class ConversationMessageTile extends StatelessWidget {
  const ConversationMessageTile({
    super.key,
    required this.message,
    required this.optionsEnabled,
    required this.onChoose,
    this.recordingBuilder,
    this.onAcceptChoice,
    this.artifactOwner,
    this.streaming = false,
  });
  final ConversationMessage message;
  final bool optionsEnabled;
  final ValueChanged<int> onChoose;
  final bool Function(int)? onAcceptChoice;
  final Widget Function(String callId, bool compact)? recordingBuilder;
  final Object? artifactOwner;
  final bool streaming;

  @override
  Widget build(BuildContext context) {
    if (message.thinking case final thinking?) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: NativeThinkingCard(
          steps: thinking.text.split('\n'),
          processing: thinking.processing && streaming,
        ),
      );
    }
    if (message.questions case final questions?) {
      final prompts = questions.items
          .map((question) => question.prompt.trim())
          .where((prompt) => prompt.isNotEmpty)
          .toList(growable: false);
      final genericSummary = {
        '需要你补充信息',
        '需要你补充信息。',
        '请补充信息',
        '请补充必要信息',
        '请语音回答',
      }.contains(message.text.trim());
      return NativeConversationTextBubble(
        bubbleKey: ValueKey('message:${message.id}'),
        text: message.text.trim().isNotEmpty && !genericSummary
            ? message.text
            : [
                questions.title,
                for (final prompt in prompts) '· $prompt',
              ].join('\n'),
      );
    }
    if (message.artifact case final artifact?) {
      if (artifactOwner == null) {
        return Text('${artifact.fileName}（请在任务详情下载）');
      }
      final card = TaskArtifactCard(artifact: artifact, owner: artifactOwner!);
      return artifact.kind == TaskArtifactKind.batchCsv
          ? Padding(padding: const EdgeInsets.only(bottom: 10), child: card)
          : card;
    }
    if (message.document case final document?) {
      return NativeDocumentCard(
        key: ValueKey('document:${document.batchId}'),
        files: document.files,
      );
    }
    if (message.batchConfirmation case final confirmation?) {
      return BatchConfirmationCard(confirmation: confirmation);
    }
    if (message.confirmation != null) {
      return CallConfirmationCard(confirmation: message.confirmation!);
    }
    if (message.receipt case final receipt?) {
      if (NativeCallReceiptPresentation(receipt).physicalResultPending) {
        if (CallOutcomeScope.awaitingFor(
          context,
          callAttemptId: receipt.attemptId,
          callId: receipt.callId,
        )) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFFFFF8E6),
                  borderRadius: BorderRadius.all(Radius.circular(18)),
                  border: Border.fromBorderSide(
                    BorderSide(color: Color(0x33C99700)),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(0xFFC99700),
                          shape: BoxShape.circle,
                        ),
                        child: SizedBox(width: 7, height: 7),
                      ),
                      SizedBox(width: 8),
                      Text(
                        '正在确认通话结果',
                        style: TextStyle(
                          fontSize: 13,
                          height: 18 / 13,
                          color: Color(0xFF8A6D1D),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        return const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '通话已结束，结果待核实',
              style: TextStyle(fontSize: 12, color: Color(0xFF677892)),
            ),
          ),
        );
      }
      return CallReceiptCard(
        receipt: receipt,
        recordingBuilder: recordingBuilder,
      );
    }
    if (message.batchReceipt case final receipt?) {
      return BatchReceiptCard(
        receipt: receipt,
        recordingBuilder: recordingBuilder,
      );
    }
    final user = message.role == MessageRole.user;
    final card = message.toolCard;
    if (message.options.isNotEmpty) {
      final apologyOption = message.id.startsWith('local:apology:');
      final options = ConversationOptionsCard(
        message: apologyOption
            ? message.copyWith(optionsTitleVisible: false)
            : message,
        enabled: optionsEnabled,
        onSelect: (index) {
          if (onAcceptChoice != null) return onAcceptChoice!(index);
          onChoose(index);
          return true;
        },
      );
      if (apologyOption &&
          message.optionsTitleVisible &&
          message.text.trim().isNotEmpty) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            NativeConversationTextBubble(text: message.text, fillWidth: true),
            options,
          ],
        );
      }
      return options;
    }
    if (card == null) {
      return NativeConversationTextBubble(
        text: message.text,
        user: user,
        copyEnabled: !streaming && message.role != MessageRole.notice,
        bubbleKey: ValueKey('message:${message.id}'),
      );
    }
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        key: ValueKey('message:${message.id}'),
        constraints: const BoxConstraints(maxWidth: 270),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: user ? null : Colors.white,
          gradient: user
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF007AFF), Color(0xFF0066DD)],
                )
              : null,
          border: Border.all(color: const Color(0xFFE8EDF2)),
          borderRadius: BorderRadius.circular(14),
          boxShadow: user
              ? null
              : const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    offset: Offset(0, 1),
                    blurRadius: 4,
                  ),
                ],
        ),
        child: _ToolContent(card: card),
      ),
    );
  }
}

class _ToolContent extends StatelessWidget {
  const _ToolContent({required this.card});
  final ConversationToolCard card;
  bool get _permission => card.toolName == 'requestPermission';
  bool get _permissionGranted => card.status.toUpperCase() == 'OK';
  String get _iconLabel => switch (card.toolName) {
    'search' => 'S',
    'askUser' => 'A',
    'showOptions' => 'O',
    'makeCall' => 'C',
    'stageReport' => 'R',
    _ =>
      card.methodLabel.isEmpty
          ? 'T'
          : card.methodLabel.characters.first.toUpperCase(),
  };
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        children: [
          ExcludeSemantics(
            child: Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F0FC),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                _iconLabel,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2196F3),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              card.methodLabel,
              style: const TextStyle(
                color: Color(0xFF007AFF),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 15 / 11,
              ),
            ),
          ),
        ],
      ),
      if (card.body.isNotEmpty)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FB),
            borderRadius: BorderRadius.circular(6),
          ),
          child: _ReadableText(
            card.body,
            style: const TextStyle(
              color: Color(0xFF667085),
              fontFamily: 'monospace',
              fontSize: 11,
              height: 16 / 11,
            ),
          ),
        ),
      if (card.result.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 5),
          // The result is server display text. Never infer success from SSE done.
          child: _ReadableText(
            '${_permission && !_permissionGranted ? '·' : '✓'} ${card.result}',
            semanticsLabel: card.result,
            style: TextStyle(
              color: _permission && !_permissionGranted
                  ? const Color(0xFF667085)
                  : const Color(0xFF34C759),
              fontSize: 11,
              height: 15 / 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
    ],
  );
}

class _ReadableText extends StatelessWidget {
  const _ReadableText(this.text, {required this.style, this.semanticsLabel});
  final String text;
  final String? semanticsLabel;
  final TextStyle style;
  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticsLabel ?? text,
    excludeSemantics: true,
    child: SelectableText(text, style: style),
  );
}
