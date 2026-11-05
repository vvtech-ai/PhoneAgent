import 'dart:async';
import '../../../../core/diagnostics/diagnostic_event.dart';
import '../../../apology/presentation/controller/apology_conversation_binding.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/agent_protocol.dart';
import '../../domain/conversation_ids.dart';
export '../../domain/conversation_ids.dart';
import '../../domain/receipts/batch_progress_tracker.dart';
import '../../domain/receipts/call_receipt.dart';
import '../../domain/history/conversation_history.dart';
import '../../domain/history/ledger_event.dart';
import '../../domain/tools/phone_contact_lookup.dart';
import '../../domain/tools/name_contact_lookup.dart';
import '../../domain/tools/conversation_permission.dart';
import '../../domain/tools/conversation_action_coordinator.dart';
import '../../../attachments/presentation/controller/agent_document_controller.dart';
import 'conversation_action_flow.dart';
import 'conversation_signal_flow.dart';
import '../../domain/tools/conversation_tool_coordinator.dart';
import '../../../contacts/domain/contact_name_matcher.dart';
import '../../../attachments/domain/document_import.dart';
import '../../../attachments/domain/ocr_history_projection.dart';
import '../../../attachments/presentation/controller/ocr_session_controller.dart';
import '../../domain/history/conversation_ocr_boundary.dart';
import 'conversation_submission_flow.dart';
import '../../domain/confirmation/call_confirmation_reply.dart';
import '../../domain/confirmation/confirmation_supplement_outbox.dart';
import '../../domain/confirmation/confirmation_supplement.dart';
import 'conversation_confirmation_binding.dart';
import 'conversation_restore_flow.dart';
import '../../domain/recovery/task_error_recovery_session.dart';
import '../../domain/voice/conversation_turn_recovery.dart';
import 'conversation_state.dart';
import 'conversation_speech_controller.dart';
import 'conversation_diagnostics.dart';
import 'conversation_event_stream.dart';
import 'conversation_event_binding.dart';
import 'conversation_failure_presentation.dart';
import 'conversation_message_store.dart';
import 'detached_batch_streams.dart';
import '../../../calls/domain/call_admission_service.dart';
import 'conversation_call_binding.dart';
import 'conversation_outcome_flow.dart';
import '../../domain/context/conversation_permission_resume.dart';
import '../../domain/stopping/conversation_stop.dart';
import 'conversation_stop_binding.dart';
import '../../../calls/domain/call_session.dart';
import '../../../calls/presentation/controller/conversation_call_controller.dart';

class ConversationController extends StateNotifier<ConversationState> {
  ConversationController({
    required ConversationEntry entry,
    required this.accountId,
    required AgentGateway gateway,
    required ConversationHistoryRepository history,
    this.attachments,
    this.documents,
    ConversationPermissionSource? permissions,
    PhoneContactLookup? contactLookup,
    NameContactLookup? nameContactLookup,
    CallAdmissionService? callAdmission,
    CallSessionRepository? callSessions,
    this.detachedBatches,
    this.taskErrors,
    this.accountIsCurrent,
    this.confirmationReplies,
    this.supplements,
    this.stopRepository,
    this.onTaskResultChanged,
    this.diagnostics,
    String Function()? nextId,
    ApologyVoiceDependencies? apologyVoice,
  }) : _stream = ConversationEventStream(gateway),
       _history = history,
       _actions = ConversationActionCoordinator(
         permissions: permissions,
         documents: documents,
       ),
       _tools = ConversationToolCoordinator(
         history: history,
         phone: contactLookup,
         names: nameContactLookup,
       ),
       _nextId = nextId ?? newConversationId,
       super(ConversationState(entry: entry)) {
    if (callAdmission != null && callSessions != null) {
      calls = bindConversationCalls(
        admission: callAdmission,
        sessions: callSessions,
        stopBatch: stopRepository == null
            ? null
            : (id) => _stopping.stopObservedBatch(id),
        accountId: accountId,
        current: () => isOpen,
        read: () => state,
        write: (value) => state = value,
        nextId: _nextId,
        messages: _live,
        publish: _publish,
        start: _start,
        prepare: () {
          speech?.begin(sessionId: state.entry.sessionId);
          _stream.cancel();
          _events.reset();
          return ++_generation;
        },
        syncOutcome: (id, observationCurrent) =>
            _outcomes.call(id, observationCurrent: observationCurrent),
        syncUnregisteredOutcome: (command, observationCurrent) async {
          await _outcomes.sync(
            _generation,
            observationCurrent: observationCurrent,
            unregisteredCommand: command,
          );
        },
        diagnostics: diagnostics,
        narrateNotice: (id, text) => speech?.speakLocalPrompt(id, text),
      );
    }
    _createApology = (restoredModel) => ApologyConversationBinding(
      dependencies: apologyVoice,
      gateway: gateway,
      messages: _live,
      read: () => state,
      write: (value) => state = value,
      publish: _publish,
      current: () => isOpen,
      nextId: _nextId,
      interrupt: () {
        calls?.pausePreparation();
        unawaited(speech?.interrupt());
      },
      cancelStream: () {
        _stream.cancel();
        ++_generation;
      },
      accountId: accountId,
      send: send,
      restoredModel: restoredModel,
    );
    apology = initialApologyBinding(entry, _createApology);
  }
  late final ApologyConversationBinding Function(String?) _createApology;
  ApologyConversationBinding? apology;
  ConversationCallController? calls;
  ConversationSpeechController? speech;
  bool get isOpen =>
      mounted &&
      state.phase != ConversationPhase.closed &&
      (accountIsCurrent?.call() ?? true);
  final bool Function()? accountIsCurrent;
  final CallConfirmationReplyRepository? confirmationReplies;
  final ConfirmationSupplementOutbox? supplements;
  final ConversationStopRepository? stopRepository;
  late final ConversationStopBinding _stopping = ConversationStopBinding(
    repository: stopRepository,
    accountId: accountId,
    detachedBatches: detachedBatches,
    sessionId: state.entry.sessionId,
    current: () => isOpen,
    read: () => state,
    write: (value) => state = value,
    messages: _live,
    batch: _batch,
    cancelPreparing: () => calls?.cancelPending(),
    cancelReplies: () => _confirmation.flow.invalidate(),
    interruptSpeech: () => speech?.pauseForResult(),
    onBatchRecovery: (id) => speech?.waitForBatch(id),
    onProgressEvent: (event, command) =>
        calls?.acceptBatchProgress(event, command),
    onBatchCompleted: () => onTaskResultChanged?.call(),
    synchronize: () => _outcomes.sync(_generation),
    generation: () => _generation,
    diagnostics: diagnostics,
  );
  bool get canStop => calls?.awaitingOutcome != true && _stopping.available;
  bool get stopping => _stopping.busy;
  Future<void> stop(Future<bool> Function(String) confirmBatch) =>
      _stopping.stop(confirmBatch);
  late final _confirmation = ConversationConfirmationBinding(
    accountId: accountId,
    sessionId: state.entry.sessionId,
    calls: () => calls,
    generation: () => _generation,
    current: () => isOpen,
    nextId: _nextId,
    messages: _live,
    publish: _publish,
    notice: showNotice,
    replies: confirmationReplies,
    readNotice: () => state.notice,
    supplements: supplements,
  );
  void showConfirmationSupplements(
    List<ConfirmationSupplement> records,
    bool failed,
  ) => _confirmation.show(records, failed);
  void reportConfirmationPresented(String identity, String signature) =>
      _confirmation.reportPresented(identity, signature);
  Future<void> retryConfirmationSupplements() async => supplements?.flush();
  String? get pendingConfirmationText => _confirmation.flow.pendingText;
  bool get canAttach =>
      isOpen && state.canSend && apology?.voice.blocked != true;
  final OcrSessionController? attachments;
  final AgentDocumentController? documents;
  ConversationOcrBoundary get ocrBoundary =>
      ConversationOcrBoundary.project(_live.facts.values, state.messages);
  String? get pendingInitialOpening =>
      _submissions.initialSent || state.entry.opening.isEmpty
      ? null
      : state.entry.opening;
  ConversationEntry? get pendingInitialEntry =>
      _submissions.initialSent ? null : state.entry;
  final String accountId;
  final ConversationEventStream _stream;
  final DetachedBatchStreams? detachedBatches;
  final TaskErrorRecoverySession? taskErrors;
  final void Function()? onTaskResultChanged;
  final DiagnosticSink? diagnostics;
  final _batch = BatchProgressTracker();
  final _live = ConversationMessageStore();
  final ConversationHistoryRepository _history;
  final ConversationToolCoordinator _tools;
  final ConversationActionCoordinator _actions;
  ContactInputSource _inputSource = ContactInputSource.typed;
  final String Function() _nextId;
  Iterable<LedgerEvent> get ledgerFacts => _live.facts.values;
  Set<String> get acceptedInputCommands =>
      Set.unmodifiable(_live.acceptedInputs);
  int _generation = 0;
  String? _executionCommand;
  final _checkedFinalErrorCommands = <String>{};
  final _unregisteredTerminalCommands = <String>{};
  String? _pendingFinalErrorCommand;
  int _pendingFinalErrorGeneration = -1;
  int _finalErrorReads = 0;
  String? _readingFinalErrorCommand;
  int _readingFinalErrorGeneration = -1;
  bool _finalErrorFailureLogged = false;
  bool _finalErrorDetached = false;
  Timer? _finalErrorRetry, _finalErrorDeadline;
  late final permissionResume = ConversationPermissionResume(() {
    _stream.cancel();
    unawaited(_outcomes.complete(++_generation, _recovery.clear));
  });
  late final ConversationOutcomeFlow _outcomes = ConversationOutcomeFlow(
    messages: _live,
    history: _history,
    batch: _batch,
    recoverBatch: (id) => _stopping.recoverBatch(id),
    current: _current,
    generation: () => _generation,
    read: () => state,
    write: (value) => state = value,
    publish: _publish,
    speech: () => speech,
    batchFinished: () => detachedBatches?.onFinished?.call(),
    resultChanged: onTaskResultChanged,
  );
  late final _submissions = ConversationSubmissionFlow(
    history: _history,
    messages: _live,
    accountId: accountId,
    nextId: _nextId,
    read: () => state,
    write: (value) => state = value,
    current: _current,
    begin: (source) {
      documents?.abandon();
      speech?.begin(sessionId: state.entry.sessionId);
      _inputSource = source;
      calls?.cancelPending();
      calls?.releaseTerminalObservation();
      _stream.cancel();
      _events.reset();
      return ++_generation;
    },
    publish: _publish,
    start: _start,
    userContext: () => attachments?.userContext,
  );
  ConversationTurnRecovery get _recovery => _submissions.recovery;
  String get recoverableInput => _recovery.baseText;
  late final _signals = ConversationSignalFlow(
    read: () => state,
    write: (value) => state = value,
    current: _current,
    messages: _live,
    tools: _tools,
    handlesAction: _actions.handles,
    inputSource: () => _inputSource,
    publish: _publish,
    accept: (e, c, g) => _events.accept(e, c, g),
    assistant: _assistant,
    notice: showNotice,
    calls: () => calls,
    actions: () => ConversationActionFlow(
      coordinator: _actions,
      read: () => state,
      write: (value) => state = value,
      messages: _live,
      nextId: _nextId,
      accountId: accountId,
      userContext: () => attachments?.userContext,
      permissionResume: permissionResume,
      beginSpeech: () => speech?.begin(sessionId: state.entry.sessionId),
      start: (command) {
        _events.reset();
        _start(command, ++_generation);
      },
    ),
  );
  late final ConversationEventFlow _events = bindConversationEvents(
    suppressInteractions: () => _stopping.suppressInteractions,
    read: () => state,
    write: (value) => state = value,
    current: _current,
    messages: _live,
    batch: _batch,
    history: _history,
    speech: () => speech,
    calls: () => calls,
    errors: taskErrors,
    cancelled: _stopping.serverCancelled,
    signal: _signals.run,
    assistant: _assistant,
    publish: _publish,
    batchFinished: () => detachedBatches?.onFinished?.call(),
    failed: (generation, failure) => _fail(generation, failure: failure),
    done: _streamCompleted,
    onCommittedExecutionError: (fact, generation, unregistered) {
      final command = fact.commandId?.trim() ?? '';
      if (command.isEmpty ||
          (command != _executionCommand &&
              !_unregisteredTerminalCommands.contains(command)) ||
          (!unregistered &&
              !_unregisteredTerminalCommands.contains(command) &&
              !_checkedFinalErrorCommands.contains(command))) {
        return;
      }
      if (_outcomes.committedCallResult(fact, command, generation)) {
        _unregisteredTerminalCommands.remove(command);
      }
      if (_pendingFinalErrorCommand == command &&
          _outcomes.hasNotifiedExecutionError(command)) {
        _clearFinalErrorCheck();
      }
    },
    onGapRecoveredFact: (fact, generation) =>
        _outcomes.recoveredCallResult(fact, generation),
    onFinalResponse: (event, command, generation) {
      final result = event.payload['callResult'];
      final receipt = CallReceipt.fromResult(ReceiptValues.object(result));
      if (command == _executionCommand &&
          calls?.activeRequest != null &&
          calls?.snapshot.call?.target.callId.isEmpty == true &&
          receipt.status.trim().isNotEmpty &&
          !receipt.isRunning) {
        _unregisteredTerminalCommands.add(command);
      }
      if (event.eventName != 'task_failed' ||
          result is! Map ||
          result['status']?.toString().trim().toUpperCase() !=
              'EXECUTION_ERROR' ||
          _executionCommand != command ||
          calls?.activeRequest == null ||
          calls?.snapshot.call?.target.callId.isEmpty != true ||
          _outcomes.hasNotifiedExecutionError(command) ||
          !_checkedFinalErrorCommands.add(command)) {
        return;
      }
      _pendingFinalErrorCommand = command;
      _pendingFinalErrorGeneration = generation;
      _finalErrorReads = 0;
      _finalErrorFailureLogged = false;
      _finalErrorDetached = false;
      _finalErrorDeadline?.cancel();
      _finalErrorDeadline = Timer(
        const Duration(minutes: 5),
        () => _expireFinalErrorCheck(command, _pendingFinalErrorGeneration),
      );
      scheduleMicrotask(
        () => unawaited(_verifyFinalExecutionError(command, generation)),
      );
    },
  );
  bool _current(int generation) => isOpen && _generation == generation;
  void toggleInput() {
    if (mounted) state = state.copy(voiceMode: !state.voiceMode);
  }

  void showNotice(String value) {
    if (mounted) state = state.copy(notice: value);
  }

  Future<void> resumeAfterInterruption() async {
    if (!isOpen) return;
    await Future.wait([
      _stopping.resumeAfterInterruption(),
      if (calls != null) calls!.refreshTerminalOutcome(),
      if (_pendingFinalErrorCommand != null)
        _verifyFinalExecutionError(
          _pendingFinalErrorCommand!,
          _pendingFinalErrorGeneration,
        ),
    ]);
  }

  Future<void> restore() async {
    if (!isOpen || _batch.active) return;
    _stopping.invalidate();
    _confirmation.flow.invalidate();
    documents?.abandon();
    _recovery.clear();
    unawaited(speech?.interrupt());
    calls?.cancelPending();
    _stream.cancel();
    final generation = ++_generation;
    await ConversationRestoreFlow.run(
      read: () => state,
      write: (value) => state = value,
      history: _history,
      messages: _live,
      attachments: attachments,
      isCurrent: () => _current(generation),
      afterProjected: _stopping.restored,
      onRestored: (restored) {
        _submissions.initialSent =
            restored.ledger == null ||
            restored.ledger!.events.any(
              (event) => event.type == 'USER_TURN_ACCEPTED',
            );
        calls?.restoreHistory(restored);
        taskErrors?.restored(restored.detail.status);
        apology = restoreApologyBinding(apology, restored, _createApology);
      },
    );
    if (_current(generation)) await supplements?.restore();
  }

  bool choose(String messageId, int index) =>
      apology?.choose(messageId, index) ??
      _submissions.choose(messageId, index, send);

  void interruptReplyForInput() {
    if (!isOpen || _batch.active || calls?.snapshot.showCall == true) return;
    if (speech?.isActive == true && state.phase == ConversationPhase.sending) {
      _stream.cancel();
      ++_generation;
      _finishToolCards();
      state = state.copy(phase: ConversationPhase.ready, activity: '');
    }
    unawaited(speech?.interrupt());
  }

  int get inputGeneration => _generation;
  ContactInputSource get inputSource => _inputSource;
  bool sendDocument(DocumentTurn turn, {ContactInputSource? source}) =>
      send(turn.payload, document: turn, source: source ?? _inputSource);

  bool send(
    String input, {
    ContactInputSource source = ContactInputSource.typed,
    DocumentTurn? document,
  }) {
    final text = input.trim();
    if (apology?.input(text, source, document) == true) {
      return true;
    }
    if (!isOpen ||
        !state.canSend ||
        text.isEmpty ||
        calls?.awaitingOutcome == true ||
        calls?.snapshot.showCall == true) {
      return false;
    }
    if (_batch.active || detachedBatches?.hasActive == true) {
      showNotice('正在执行多路外呼，完成后会汇总结果');
      return false;
    }
    final confirmation = document == null
        ? _confirmation.flow.handle(
            text,
            () => _submitTurn(text, source, document),
          )
        : null;
    if (confirmation != null) return confirmation;
    return _submitTurn(text, source, document);
  }

  bool _submitTurn(
    String text,
    ContactInputSource source,
    DocumentTurn? document,
  ) {
    bool submit() => _submissions.send(text, source, document);
    if (calls?.interceptSubmission(submit) == true) {
      state = state.copy(phase: ConversationPhase.sending, activity: '正在刷新积分…');
      return true;
    }
    return submit();
  }

  void _start(AgentCommand command, int generation) {
    if (apology?.voice.blocked == true) {
      state = state.copy(phase: ConversationPhase.ready, activity: '');
      return;
    }
    if (apology != null) command = apology!.command(command);
    final pendingFinalError = _pendingFinalErrorCommand;
    if (pendingFinalError == null) {
      _clearFinalErrorCheck();
    } else {
      // The newer turn owns the screen; the older result check may update the
      // task list only, while retaining its original deadline.
      _finalErrorDetached = true;
      _pendingFinalErrorGeneration = generation;
      _finalErrorRetry?.cancel();
      _finalErrorRetry = null;
      scheduleMicrotask(
        () => unawaited(
          _verifyFinalExecutionError(pendingFinalError, generation),
        ),
      );
    }
    _executionCommand = command.actionId == 'confirm_call'
        ? command.commandId
        : null;
    _stopping.started(command.commandId);
    _recovery.started(command);
    _stream.start(
      command,
      isCurrent: () => _current(generation),
      accept: (event) => _events.accept(event, command.commandId, generation),
      onError: (error) {
        traceConversationFailure(state.entry.sessionId, error);
        _fail(generation, failure: error);
      },
      onDone: () => _streamCompleted(command.commandId, generation),
    );
  }

  Future<void> _streamCompleted(String command, int generation) =>
      _outcomes.complete(generation, () => _recovery.completed(command));

  Future<void> _verifyFinalExecutionError(
    String command,
    int generation,
  ) async {
    if (!isOpen) {
      _clearFinalErrorCheck();
      return;
    }
    if (!_currentFinalErrorCheck(command, generation) ||
        (_readingFinalErrorCommand == command &&
            _readingFinalErrorGeneration == generation)) {
      return;
    }
    if (_outcomes.hasNotifiedExecutionError(command)) {
      _clearFinalErrorCheck();
      return;
    }
    _finalErrorRetry?.cancel();
    _finalErrorRetry = null;
    _readingFinalErrorCommand = command;
    _readingFinalErrorGeneration = generation;
    _finalErrorReads++;
    try {
      if (_finalErrorDetached) {
        await _outcomes.readCommittedExecutionError(command, generation);
      } else {
        await _outcomes.sync(
          generation,
          observationCurrent: () =>
              _currentFinalErrorCheck(command, generation),
          unregisteredCommand: command,
        );
      }
    } catch (error) {
      if (_currentFinalErrorCheck(command, generation) &&
          !_finalErrorFailureLogged) {
        _finalErrorFailureLogged = true;
        emitDiagnostic(
          diagnostics,
          DiagnosticEvent(
            operation: DiagnosticOperation.taskResultRead,
            result: DiagnosticResult.failed,
            failureKind: error is TimeoutException
                ? DiagnosticFailureKind.timeout
                : error is FormatException
                ? DiagnosticFailureKind.format
                : error is StateError
                ? DiagnosticFailureKind.state
                : DiagnosticFailureKind.other,
            sessionId: state.entry.sessionId,
          ),
        );
      }
    } finally {
      if (!isOpen) _clearFinalErrorCheck();
      if (_readingFinalErrorCommand == command &&
          _readingFinalErrorGeneration == generation) {
        _readingFinalErrorCommand = null;
        _readingFinalErrorGeneration = -1;
      }
      if (_currentFinalErrorCheck(command, generation)) {
        if (_outcomes.hasNotifiedExecutionError(command) ||
            _finalErrorReads >= 32) {
          _clearFinalErrorCheck();
        } else {
          _finalErrorRetry = Timer(
            const Duration(milliseconds: 1500),
            () => unawaited(_verifyFinalExecutionError(command, generation)),
          );
        }
      }
    }
  }

  bool _currentFinalErrorCheck(String command, int generation) =>
      _current(generation) &&
      _pendingFinalErrorCommand == command &&
      _pendingFinalErrorGeneration == generation;

  void _expireFinalErrorCheck(String command, int generation) {
    if (_pendingFinalErrorCommand != command ||
        _pendingFinalErrorGeneration != generation) {
      return;
    }
    _finalErrorReads = 32;
    _finalErrorRetry?.cancel();
    _finalErrorRetry = null;
    if (_readingFinalErrorCommand != command ||
        _readingFinalErrorGeneration != generation) {
      _clearFinalErrorCheck();
    }
  }

  void _clearFinalErrorCheck() {
    _finalErrorRetry?.cancel();
    _finalErrorDeadline?.cancel();
    _finalErrorRetry = null;
    _finalErrorDeadline = null;
    _pendingFinalErrorCommand = null;
    _pendingFinalErrorGeneration = -1;
    _finalErrorDetached = false;
  }

  void _assistant(String command, String text) {
    _live.assistant(command, text, const [], null);
    _publish();
  }

  void _publish() {
    attachments?.synchronize(
      OcrHistoryProjection.project(state.entry.sessionId, _live.facts.values),
    );
    state = _live.project(state);
    _stopping.reconcile();
    calls?.acceptReceipts(state.messages);
    speech?.project(_live.facts.values, state.messages);
  }

  void _fail(int generation, {Object? failure}) {
    if (!_current(generation)) return;
    taskErrors?.failed(
      failure,
      hasCallContext: _batch.active || calls?.activeRequest != null,
    );
    _recovery.failed(
      failure,
      ordinaryTurn: !_batch.active && calls?.activeRequest == null,
    );
    if (_recovery.pending) _live.discardPartialReply(_recovery.commandId!);
    if (_batch.active) {
      _batch.markUncertain();
      _live.batch(_batch.command, _batch.snapshot());
      _stream.cancel();
      ++_generation;
      state = _live
          .project(state)
          .copy(
            phase: ConversationPhase.ready,
            activity: '外呼请求失败，正在核对拨号状态，请稍后刷新',
          );
      speech?.waitForBatch(_batch.batchId);
      _stopping.recoverBatch(_batch.batchId);
      return;
    }
    unawaited(speech?.interrupt());
    _stream.cancel();
    if (failure != null) calls?.confirmationFailed(failure);
    calls?.cancelPending();
    _finishToolCards();
    ++_generation;
    state = ConversationFailurePresentation.apply(
      state,
      failure,
      hasActiveCall: calls?.activeRequest != null,
      recoverableInput: _recovery.pending,
    );
  }

  void _finishToolCards() {
    _live.finishTools();
    _publish();
  }

  void close() {
    if (!mounted || state.phase == ConversationPhase.closed) return;
    apology?.close();
    _stopping.invalidate();
    _confirmation.flow.close();
    documents?.abandon();
    taskErrors?.close();
    _recovery.clear();
    _clearFinalErrorCheck();
    unawaited(speech?.interrupt());
    ++_generation;
    if (!_batch.active || detachedBatches?.retain(_stream) != true) {
      _stream.cancel();
    }
    _batch.clear();
    calls?.close();
    attachments?.close();
    _live.clear();
    state = state.copy(
      phase: ConversationPhase.closed,
      messages: const [],
      clearOptions: true,
    );
  }

  @override
  void dispose() {
    close();
    speech?.dispose();
    calls?.dispose();
    attachments?.dispose();
    documents?.dispose();
    super.dispose();
  }
}
