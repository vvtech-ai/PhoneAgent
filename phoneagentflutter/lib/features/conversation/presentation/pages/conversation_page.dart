import 'package:flutter/material.dart';
import '../widgets/native_conversation_wave.dart';
import '../widgets/conversation_status_presentation.dart';
import '../widgets/conversation_batch_activity.dart';
import '../widgets/native_conversation_timeline.dart';
import '../widgets/conversation_content_revision.dart';
import '../controller/conversation_state.dart';
import '../widgets/conversation_composer.dart';
import '../widgets/native_thinking_card.dart';
import '../widgets/conversation_header.dart';
import '../widgets/location_permission_notice.dart';
import '../widgets/conversation_message_tile.dart';
import '../widgets/native_conversation_text_bubble.dart';
import '../../domain/conversation_messages.dart';
import '../../../apology/domain/apology_voice.dart';
import '../../domain/batch_confirmation_focus.dart';
import '../../domain/conversation_thinking_presentation.dart';
import '../../domain/receipts/native_call_receipt_presentation.dart';
import '../../domain/tools/conversation_permission.dart';
import '../widgets/conversation_timeline_attachment.dart';
import '../widgets/voice_composer_binding.dart';
import '../controller/task_draft_controller.dart';
import '../widgets/conversation_precheck_presentation.dart';
import '../widgets/native_conversation_precheck_card.dart';
import '../../../calls/presentation/widgets/call_outcome_scope.dart';

class ConversationPage extends StatelessWidget {
  const ConversationPage({
    super.key,
    required this.state,
    required this.modelName,
    required this.onClose,
    required this.onToggle,
    required this.onSend,
    required this.onChoose,
    required this.onRetry,
    required this.onNotice,
    required this.onModels,
    this.receiptFeedbackBuilder,
    this.confirmationBuilder,
    this.recordingBuilder,
    this.onAttachments,
    this.attachments = const [],
    this.voice,
    this.attachmentBusy = false,
    this.onRetrySupplements,
    this.onStop,
    this.stopping = false,
    this.draft,
    this.artifactOwner,
    this.precheckStatus = '',
    this.precheckBlocked = false,
    this.precheck,
    this.onPermissionSettings,
  });
  final ConversationState state;
  final bool attachmentBusy;
  final VoiceComposerBinding? voice;
  final String modelName;
  final VoidCallback onClose, onToggle, onRetry, onModels;
  final VoidCallback? onAttachments;
  final VoidCallback? onRetrySupplements;
  final VoidCallback? onStop;
  final bool stopping;
  final String precheckStatus;
  final bool precheckBlocked;
  final ConversationPrecheckPresentation? precheck;
  final VoidCallback? onPermissionSettings;
  final TaskDraftController? draft;
  final Object? artifactOwner;
  final List<ConversationTimelineAttachment> attachments;
  final bool Function(String) onSend;
  final bool Function(String, int) onChoose;
  final ValueChanged<String> onNotice;
  final Widget? Function(ConversationMessage)? receiptFeedbackBuilder;
  final Widget Function(ConversationMessage, int ordinal)? confirmationBuilder;
  final Widget Function(String callId, bool compact)? recordingBuilder;
  bool get _stopUnconfirmed =>
      stopping && state.notice == batchUnconfirmedNotice;
  bool get _requiresRecovery =>
      state.phase == ConversationPhase.recoveryRequired ||
      state.phase == ConversationPhase.restoreFailed;
  bool get _currentThinking => state.messages.any(
    (m) =>
        m.thinking?.processing == true &&
        m.commandId ==
            state.messages
                .where((m) => m.role == MessageRole.user)
                .lastOrNull
                ?.commandId,
  );
  ConversationBatchActivity get _batchActivity =>
      ConversationBatchActivity.from(state);
  bool get _thinking =>
      (state.phase == ConversationPhase.sending ||
          state.preparingCall ||
          _batchActivity.active) &&
      state.transientStatus.isEmpty &&
      precheck?.visible != true &&
      !_currentThinking;
  bool get _awaitingBatchOutcome => _batchActivity.awaitingResult;
  String get _liveTranscript =>
      state.voiceMode ? voice?.state.text.trim() ?? '' : '';

  bool get _showEntryOpening =>
      !state.entry.restore &&
      state.entry.skillId != ApologyVoicePolicy.skillId &&
      state.entry.opening.trim().isNotEmpty &&
      !state.messages
          .takeWhile((m) => m.role != MessageRole.user)
          .any(
            (m) =>
                !m.transient &&
                m.role == MessageRole.assistant &&
                (m.commandId == 'initial-opening:${state.entry.sessionId}' ||
                    m.text.trim() == state.entry.opening.trim()),
          );

  NativeConversationWaveMode get _waveMode =>
      ConversationStatusPresentation.from(
        state,
        voice,
        precheck: precheckStatus,
      ).waveMode;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.transparent,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final awaitingOutcome =
            CallOutcomeScope.awaitingOf(context) || _awaitingBatchOutcome;
        final awaitingPhysicalCallResult =
            CallOutcomeScope.awaitingOf(context) &&
            state.messages.any((message) {
              final receipt = message.receipt;
              return receipt != null &&
                  NativeCallReceiptPresentation(
                    receipt,
                  ).physicalResultPending &&
                  CallOutcomeScope.awaitingFor(
                    context,
                    callAttemptId: receipt.attemptId,
                    callId: receipt.callId,
                  );
            });
        final preview = CallOutcomeScope.previewOf(context);
        final provisional = preview == null
            ? ''
            : [
                '暂定判断：${preview.headline.isEmpty ? '通话结果待核实' : preview.headline}',
                if (preview.detail.isNotEmpty) preview.detail,
                '仍在等待最终回执',
              ].join('\n');
        final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final compact =
            constraints.maxHeight < 700 &&
            constraints.maxHeight < 420 * textScale;
        final status = ConversationStatusPresentation.from(
          state,
          voice,
          precheck: precheckStatus,
          awaitingOutcome: awaitingOutcome,
        ).label;
        final empty =
            state.messages.isEmpty &&
            attachments.isEmpty &&
            !_thinking &&
            !awaitingOutcome &&
            _liveTranscript.isEmpty;
        final feedback = <Widget>[
          if (state.notice.isNotEmpty &&
              !isLocationPermissionToast(state.notice) &&
              !_requiresRecovery &&
              !_stopUnconfirmed)
            Text(
              state.notice,
              style: const TextStyle(fontSize: 12, color: Color(0xFF8B5B13)),
            ),
          if (state.notice.startsWith('补充问答保存失败') && onRetrySupplements != null)
            TextButton(
              onPressed: onRetrySupplements,
              child: const Text('重试保存补充问答'),
            ),
          if (state.notice == locationPermissionSettingsNotice &&
              onPermissionSettings != null)
            TextButton(
              onPressed: state.canSend ? onPermissionSettings : null,
              child: const Text('去设置'),
            ),
        ];
        return Column(
          children: [
            LocationPermissionNotice(
              notice: state.notice,
              onNotice: onNotice,
              active:
                  state.phase != ConversationPhase.closed &&
                  state.phase != ConversationPhase.restoring &&
                  !_requiresRecovery,
            ),
            ConversationHeader(
              onClose: onClose,
              status: status,
              showDetails: !compact || state.transientStatus.isNotEmpty,
              progress: state.progress,
              waveMode: _waveMode,
              aiSpeechEnabled: voice?.aiSpeechEnabled ?? true,
              onToggleSpeech: voice?.onToggleSpeech,
              onStatusTap: _requiresRecovery
                  ? onRetry
                  : state.transientStatus.isNotEmpty
                  ? onStop
                  : null,
            ),
            if (state.phase == ConversationPhase.restoring)
              const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: _timeline(
                feedback,
                empty,
                compact,
                status,
                awaitingOutcome,
                awaitingPhysicalCallResult,
                provisional,
              ),
            ),
            ConversationComposer(
              compact: compact,
              draft: draft,
              voice: voice,
              onStop: awaitingOutcome ? null : onStop,
              stopping:
                  stopping ||
                  awaitingOutcome && voice?.canInterruptReply != true,
              inputBlocked: precheckBlocked,
              auxiliaryEnabled:
                  !state.preparingCall && !awaitingOutcome && !stopping,
              voiceMode: state.voiceMode,
              canSend:
                  state.canSend &&
                  !attachmentBusy &&
                  !precheckBlocked &&
                  !awaitingOutcome &&
                  !stopping,
              modelName: modelName,
              onToggle: onToggle,
              onSend: onSend,
              onNotice: onNotice,
              onModels: onModels,
              onAttachments: onAttachments,
            ),
          ],
        );
      },
    ),
  );

  Widget _timeline(
    List<Widget> feedback,
    bool empty,
    bool compact,
    String status,
    bool awaitingOutcome,
    bool awaitingPhysicalCallResult,
    String provisional,
  ) => NativeConversationTimeline(
    reverse: !empty,
    inputRevision: (state.voiceMode, voice?.state.phase),
    sentRevision: state.messages
        .where((m) => m.role == MessageRole.user)
        .lastOrNull
        ?.id,
    focusItemKey: switch (state.canSend
        ? pendingBatchConfirmationFocus(state.messages)
        : null) {
      final String id => ValueKey(id),
      _ => null,
    },
    tailRevision: ConversationContentRevision(
      state.entry.sessionId,
      state.messages,
      liveTranscript: _liveTranscript,
      precheckValues: [
        awaitingOutcome,
        stopping,
        if (stopping) state.transientStatus,
        provisional,
        if (_thinking) state.activity,
        precheck?.visible,
        if (precheck?.visible == true)
          for (final item in precheck!.items) ...[item.detail, item.state],
      ],
    ),
    padding: EdgeInsets.fromLTRB(16, compact ? 14 : 10, 16, 12),
    children: [
      if (precheck?.visible == true && !empty)
        NativeConversationPrecheckCard(
          key: const ValueKey('precheck-inline'),
          state: precheck!,
          inline: true,
        ),
      if (empty &&
          compact &&
          precheck?.visible != true &&
          state.transientStatus.isEmpty)
        _compactStatus(status),
      if (_liveTranscript.isNotEmpty)
        NativeConversationTextBubble(
          key: const ValueKey('voice-transcript'),
          text: _liveTranscript,
          user: true,
        ),
      if (stopping ||
          !awaitingPhysicalCallResult &&
              (_thinking || awaitingOutcome && !_currentThinking))
        Padding(
          key: const ValueKey('conversation-thinking'),
          padding: const EdgeInsets.only(bottom: 12),
          child: NativeThinkingCard(
            title: 'Phone Agent',
            processing: !_stopUnconfirmed && _batchActivity.processing,
            sectionTitle: stopping || !_batchActivity.processing
                ? '任务处理进度'
                : 'AI 思考过程',
            steps: [
              if (provisional.isNotEmpty) provisional,
              _stopUnconfirmed
                  ? '结果尚未确认，请稍后同步'
                  : awaitingOutcome
                  ? '正在整理通话结果'
                  : stopping
                  ? state.transientStatus == '正在停止任务…'
                        ? '正在停止任务…'
                        : '正在等待任务结束…'
                  : _batchActivity.active
                  ? _batchActivity.detail
                  : state.activity.trim().isNotEmpty &&
                        state.activity != '正在思考…'
                  ? state.activity
                  : ConversationThinkingPresentation.fallback(
                      state.entry.skillId,
                    ),
            ],
          ),
        ),
      if (!empty) ...feedback.reversed,
      ...withTimelineAttachments([
        for (final message in state.messages)
          Column(
            key: ValueKey(message.id),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((message.confirmation != null ||
                      message.batchConfirmation != null) &&
                  confirmationBuilder != null)
                confirmationBuilder!(
                  message,
                  state.messages
                          .takeWhile((item) => item.id != message.id)
                          .where((item) => item.confirmation != null)
                          .length +
                      1,
                )
              else
                ConversationMessageTile(
                  message: message,
                  streaming:
                      message.transient &&
                      message.role == MessageRole.assistant &&
                      !state.canSend &&
                      message.commandId ==
                          state.messages
                              .where((m) => m.role == MessageRole.user)
                              .lastOrNull
                              ?.commandId,
                  optionsEnabled:
                      state.canSend &&
                      !attachmentBusy &&
                      state.activeOptionsId == message.id,
                  onChoose: (index) => onChoose(message.id, index),
                  onAcceptChoice: (index) => onChoose(message.id, index),
                  recordingBuilder: recordingBuilder,
                  artifactOwner: artifactOwner,
                ),
              if (receiptFeedbackBuilder?.call(message)
                  case final Widget feedback)
                feedback,
            ],
          ),
      ], attachments).reversed,
      if (_showEntryOpening && precheck?.visible != true)
        ConversationMessageTile(
          key: const ValueKey('conversation-entry-opening'),
          // Presentation only; this does not append a history/ledger fact.
          message: ConversationMessage(
            id: 'entry-opening:${state.entry.sessionId}',
            role: MessageRole.assistant,
            text: state.entry.opening,
          ),
          optionsEnabled: false,
          onChoose: (_) {},
        ),
      if (empty && precheck?.visible == true)
        NativeConversationPrecheckCard(
          key: const ValueKey('precheck-entry'),
          state: precheck!,
        ),
      if (empty && precheck?.visible != true) ...feedback,
      if (!empty && compact) _compactStatus(status),
    ],
  );

  Widget _compactStatus(String status) => ConversationHeaderDetails(
    status: status,
    horizontalPadding: 0,
    progress: state.progress,
    waveMode: _waveMode,
    aiSpeechEnabled: voice?.aiSpeechEnabled ?? true,
    onToggleSpeech: voice?.onToggleSpeech,
    onStatusTap: _requiresRecovery ? onRetry : null,
  );
}
