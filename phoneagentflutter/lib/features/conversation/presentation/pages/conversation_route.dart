import '../../../../core/design/native_confirmation_dialog.dart';
import '../widgets/native_conversation_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/business_providers.dart';
import '../../../../app/diagnostics_providers.dart';
import '../../../../app/attachment_providers.dart';
import '../../../../core/design/native_notice.dart';
import '../../../attachments/presentation/widgets/conversation_document_host.dart';
import '../../../attachments/domain/document_submission_context.dart';
import '../../../../app/conversation_providers.dart';
import '../../../../app/call_monitor_providers.dart';
import '../../../call_models/presentation/pages/call_model_sheet.dart';
import '../../../call_models/domain/call_models.dart';
import '../controller/conversation_state.dart';
import 'conversation_page.dart';
import '../../../feedback/presentation/pages/call_evaluation_route.dart';
import '../../../attachments/presentation/pages/conversation_attachments.dart';
import '../../../calls/presentation/pages/conversation_call_host.dart';
import '../../../attachments/presentation/widgets/conversation_ocr_host.dart';
import '../../../attachments/presentation/widgets/agent_document_host.dart';
import '../widgets/receipts/conversation_recording_host.dart';
import '../widgets/conversation_voice_host.dart';
import '../../../calls/domain/confirmation_billing.dart';
import '../../../calls/presentation/pages/confirmation_billing_route.dart';
import '../../../calls/presentation/pages/batch_confirmation_billing_route.dart';
import '../widgets/confirmation_presentation_reporter.dart';
import '../../../../app/task_draft_providers.dart';
import '../../../../app/task_artifact_providers.dart';
import '../../../../app/conversation_precheck_providers.dart';
import '../widgets/conversation_result_read_host.dart';
import '../../../../app/restaurant_memory_providers.dart';
import '../widgets/restaurant_memory_offer_host.dart';
import '../../domain/context/restaurant_contact_memory_offer.dart';
import '../../domain/confirmation/current_call_confirmation_gate.dart';
import '../widgets/task_entry_permission_guard.dart';

class ConversationRoute extends ConsumerStatefulWidget {
  const ConversationRoute({super.key, required this.entry});
  final ConversationEntry entry;
  @override
  ConsumerState<ConversationRoute> createState() => _ConversationRouteState();
}

class _ConversationRouteState extends ConsumerState<ConversationRoute> {
  late final int? _epoch;
  late final ConversationEntry entry;
  bool _permissionSettingsBusy = false;

  Future<void> _openPermissionSettings() async {
    final controller = ref.read(conversationControllerProvider(entry).notifier);
    final generation = controller.inputGeneration;
    bool current() =>
        mounted &&
        controller.isOpen &&
        controller.inputGeneration == generation &&
        ref.read(loginEpochProvider) == _epoch &&
        ModalRoute.of(context)?.isCurrent == true &&
        ref.read(conversationControllerProvider(entry)).canSend &&
        controller.calls?.activeRequest == null;
    if (_permissionSettingsBusy || !current()) return;
    _permissionSettingsBusy = true;
    try {
      if (await openTaskLocationSettings(context, current) && current()) {
        controller.send('重新获取定位');
      }
    } finally {
      _permissionSettingsBusy = false;
    }
  }

  @override
  void initState() {
    super.initState();
    _epoch = widget.entry.ownerEpoch ?? ref.read(loginEpochProvider);
    final original = widget.entry;
    entry = original.ownerEpoch != null || _epoch == null
        ? original
        : ConversationEntry(
            sessionId: original.sessionId,
            title: original.title,
            restore: original.restore,
            skillId: original.skillId,
            opening: original.opening,
            selectedContact: original.selectedContact,
            ownerEpoch: _epoch,
          );
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(loginEpochProvider) != _epoch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ModalRoute.of(context)?.isCurrent == true) {
          Navigator.of(context).pop();
        }
      });
      return const Scaffold(body: Center(child: Text('账号已切换')));
    }
    final state = ref.watch(conversationControllerProvider(entry));
    final controller = ref.read(conversationControllerProvider(entry).notifier);
    if (state.messages.any((message) => message.artifact != null)) {
      ref.watch(taskArtifactDownloadProvider(controller).notifier);
    }
    final draft = ref.watch(taskDraftProvider(entry));
    final models = ref.watch(callModelControllerProvider);
    final taskModel = controller.apology?.voice.modelId;
    final selectedModel =
        models.catalog?.models
            .where(
              (m) =>
                  m.available &&
                  normalizeProvider(m.id) == normalizeProvider(taskModel ?? ''),
            )
            .firstOrNull ??
        models.catalog?.current;
    final multiplier = selectedModel?.multiplier;
    final modelLabel = [
      selectedModel?.name ?? '选择模型',
      if (multiplier != null && multiplier.isFinite && multiplier > 0)
        '×${multiplier.toStringAsFixed(1)}',
    ].join(' ');
    final precheck = ref.watch(conversationPrecheckProvider(entry));
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) controller.close();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: RestaurantMemoryOfferHost(
          key: ValueKey('memory:${identityHashCode(controller)}'),
          hasOffer:
              state.pendingToolCallId != null &&
              state.messages.any(
                (message) =>
                    message.toolCallId == state.pendingToolCallId &&
                    (message.questions?.items.any(
                          (item) =>
                              item.id ==
                              RestaurantContactMemoryOffer.questionId,
                        ) ??
                        false),
              ),
          isCurrent: () =>
              controller.isOpen && ref.read(loginEpochProvider) == _epoch,
          onShown: (visible) =>
              ref.read(restaurantContactMemoryOfferProvider).shown(visible),
          child: ConversationResultReadHost(
            key: ValueKey(controller),
            sessionId: entry.sessionId,
            messages: state.messages,
            diagnostic: taskResultReadDiagnostics(
              ref.watch(diagnosticJournalProvider).record,
            ),
            isCurrent: () =>
                controller.isOpen && ref.read(loginEpochProvider) == _epoch,
            markRead: (target) async {
              if (ref.read(loginEpochProvider) != _epoch) {
                return;
              }
              final marked = await ref
                  .read(taskControllerProvider.notifier)
                  .markReadRef(target);
              if (!marked) {
                throw StateError('result read acknowledgement failed');
              }
            },
            child: NativeConversationBackground(
              child: ConversationDocumentHost(
                key: ValueKey(controller),
                createController: ref.watch(documentImportFactoryProvider),
                isCurrent: () => controller.isOpen,
                canStart: () =>
                    controller.canAttach &&
                    controller.attachments?.snapshot.busy != true,
                anchor: () => controller.ocrBoundary.displayBoundaryFor(
                  controller.ocrBoundary.sourceAnchor,
                ),
                onReady: controller.sendDocument,
                captureSubmission: () {
                  final selected = ref.read(
                    conversationControllerProvider(entry),
                  );
                  final submission = DocumentSubmissionContext(
                    sessionId: selected.entry.sessionId,
                    generation: controller.inputGeneration,
                    voiceMode: selected.voiceMode,
                    initialSource: controller.inputSource,
                  );
                  return (turn) {
                    if (!mounted ||
                        !controller.isOpen ||
                        ref.read(loginEpochProvider) != _epoch) {
                      return false;
                    }
                    final current = ref.read(
                      conversationControllerProvider(entry),
                    );
                    if (!submission.accepts(
                      current.entry.sessionId,
                      controller.inputGeneration,
                    )) {
                      return false;
                    }
                    return controller.sendDocument(
                      turn,
                      source: submission.submissionSource(
                        controller.inputSource,
                        voiceMode: current.voiceMode,
                      ),
                    );
                  };
                },
                onNotice: (message) => showNativeNotice(context, message),
                builder: (documentAttachments, documentBusy, openDocuments) =>
                    AgentDocumentHost(
                      controller: controller.documents,
                      child: ConversationVoiceHost(
                        entry: entry,
                        inputBlocked: precheck.blocked,
                        builder: (voice) => ConversationRecordingHost(
                          voiceMode: state.voiceMode,
                          calls: controller.calls,
                          builder: (recordingBuilder) => ConversationCallHost(
                            createMonitor: controller.calls == null
                                ? null
                                : ref.watch(callMonitorFactoryProvider),
                            controller: controller.calls,
                            modelName: selectedModel?.name ?? '选择模型',
                            child: SafeArea(
                              child: ConversationOcrHost(
                                controller: controller.attachments,
                                boundary: controller.ocrBoundary,
                                builder: (attachments) => ConversationPage(
                                  precheck: precheck.presentation,
                                  precheckStatus: precheck.label,
                                  precheckBlocked: precheck.blocked,
                                  artifactOwner: controller,
                                  draft: draft,
                                  confirmationBuilder: (message, ordinal) {
                                    final request = controller
                                        .calls
                                        ?.snapshot
                                        .launch
                                        .request;
                                    final currentCard =
                                        CurrentCallConfirmationGate.matches(
                                          message: message,
                                          request: request,
                                          messages: state.messages,
                                        );
                                    final card =
                                        message.batchConfirmation != null
                                        ? BatchConfirmationBillingRoute(
                                            sessionId: state.entry.sessionId,
                                            executable:
                                                ConfirmationBillingRequest.currentBatch(
                                                  message, state.messages,
                                                ),
                                            confirmation:
                                                message.batchConfirmation!,
                                          )
                                        : ConfirmationBillingRoute(
                                            request:
                                                ConfirmationBillingRequest.forMessage(
                                                  state.entry.sessionId,
                                                  message,
                                                  ordinal,
                                                ),
                                            confirmation: message.confirmation!,
                                            executable:
                                                currentCard &&
                                                controller
                                                        .calls
                                                        ?.activeRequest ==
                                                    null,
                                          );
                                    if (!currentCard || request == null) {
                                      return card;
                                    }
                                    return ConfirmationPresentationReporter(
                                      key: ValueKey(
                                        '${request.identity}:${request.specSignature}',
                                      ),
                                      onPresented: () => controller
                                          .reportConfirmationPresented(
                                            request.identity,
                                            request.specSignature,
                                          ),
                                      child: card,
                                    );
                                  },
                                  voice: voice,
                                  recordingBuilder: recordingBuilder,
                                  attachments: [
                                    ...attachments,
                                    ...documentAttachments,
                                  ],
                                  attachmentBusy: documentBusy,
                                  state: documentBusy
                                      ? state.copy(activity: '正在理解文档')
                                      : state,
                                  receiptFeedbackBuilder:
                                      CallEvaluationRoute.forReceipt,
                                  modelName: modelLabel,
                                  onClose: () {
                                    controller.close();
                                    Navigator.of(context).pop();
                                  },
                                  onToggle: controller.toggleInput,
                                  onSend: (text) =>
                                      !documentBusy && controller.send(text),
                                  onChoose: (id, index) =>
                                      !documentBusy &&
                                      controller.choose(id, index),
                                  onRetry: controller.restore,
                                  stopping: controller.stopping,
                                  onStop: !controller.canStop
                                      ? null
                                      : () => controller.stop(
                                          (batch) async =>
                                              await showDialog<bool>(
                                                context: context,
                                                builder: (dialog) =>
                                                    NativeConfirmationDialog(
                                                      title: '停止批量任务？',
                                                      message:
                                                          '将取消尚未拨打的任务，并请求挂断进行中的外呼。已完成的结果会保留。',
                                                      dismissLabel: '继续执行',
                                                      confirmLabel: '确认停止',
                                                      danger: true,
                                                    ),
                                              ) ==
                                              true,
                                        ),
                                  onRetrySupplements:
                                      controller.retryConfirmationSupplements,
                                  onNotice: controller.showNotice,
                                  onPermissionSettings: _openPermissionSettings,
                                  onAttachments: () =>
                                      openConversationAttachments(
                                        context,
                                        ref,
                                        controller,
                                        canSend: state.canSend && !documentBusy,
                                        openDocuments: openDocuments,
                                      ),
                                  onModels: () async {
                                    final selected = await CallModelSheet.open(
                                      context,
                                      selectedModelId:
                                          controller.apology?.voice.modelId,
                                    );
                                    if (mounted &&
                                        controller.isOpen &&
                                        ref.read(loginEpochProvider) ==
                                            _epoch &&
                                        selected != null) {
                                      controller.apology?.voice.modelChanged(
                                        selected.id,
                                      );
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
