import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/diagnostics/diagnostic_event.dart';
import '../../domain/agent_protocol.dart';
import '../../domain/membership_denial_reply.dart';
import '../../domain/voice/reply_speech_playback.dart';
import '../../domain/voice/reply_speech_start.dart';
import '../../domain/voice/speech_text_policy.dart';
import '../../domain/voice/speech_prompt_policy.dart';
import '../../domain/voice/committed_reply_narration.dart';
import '../../domain/history/ledger_event.dart';
import '../../domain/conversation_messages.dart';
import '../../domain/memory_notice.dart';

/// Reply narration only. Does not own Agent requests, task or microphone state.
class ConversationSpeechController extends ChangeNotifier {
  ConversationSpeechController({
    required this.factory,
    required this.enabled,
    this.gateDecision,
    this.diagnostics,
  });
  final ReplySpeechFactory factory;
  final bool Function() enabled;
  final DiagnosticTtsNarrationDecision Function()? gateDecision;
  final DiagnosticSink? diagnostics;
  final results = CommittedReplyNarration();
  String _resultSession = '';
  ({String eventId, int sequence})? _visibleResult;
  ({String eventId, int sequence})? _waitingResultIdentity;
  final _recordedResultDecisions = <String>{};
  String _batchNarrationId = '';
  String _lastBatchNarrationDiagnostic = '';
  bool _resultAllowed = false;
  DiagnosticBatchResultReason? _resultLossReason;
  String? _waitingResult;
  int _resultHandoffRetries = 0;
  ReplySpeechPlayback? _playback;
  ReplySpeechStart? _speechStart;
  final SpeechMarkdownStream _markdown = SpeechMarkdownStream();
  String _buffer = '';
  Timer? _first;
  int _generation = 0;
  int _stopsPending = 0;
  bool _closed = false, _interrupted = false, _sealed = false;
  bool _paused = false, _failed = false;
  bool _foreground = true;
  bool _openingHandled = false;
  final Set<String> _localPrompts = {};
  void speakLocalPrompt(String id, String text) {
    if (_closed || !enabled() || _localPrompts.contains(id)) return;
    _openingHandled = true;
    _localPrompts.add(id);
    begin();
    _resultAllowed = false;
    _enqueue(text);
    finish();
  }

  final Set<String> _spokenConfirmations = {};
  final Set<String> _spokenQuestions = {};
  String _questionSession = '';
  bool get _eligible => !_closed && !_interrupted && _foreground && enabled();
  ReplySpeechPhase? get phase => _playback?.phase;
  int get queuedBytes => _playback?.queuedBytes ?? 0;
  bool get isActive =>
      phase == ReplySpeechPhase.draining ||
      (phase == ReplySpeechPhase.accepting &&
          (queuedBytes > 0 ||
              _playback!.synthesizing ||
              _playback!.hasPendingText));
  String get status {
    if (_failed ||
        _playback?.failures != 0 && _playback != null ||
        phase == ReplySpeechPhase.failed) {
      return '播报失败，可继续文字交互';
    }
    if (_paused) return '播报已暂停，可继续交流';
    if (phase == ReplySpeechPhase.draining) return '正在播报…';
    if (phase == ReplySpeechPhase.accepting &&
        (queuedBytes > 0 || _playback!.synthesizing)) {
      return '正在播报…';
    }
    return '';
  }

  void begin({String sessionId = ''}) {
    unawaited(interrupt());
    results.begin(sessionId);
    _resultSession = sessionId;
    _visibleResult = null;
    _waitingResultIdentity = null;
    _resultHandoffRetries = 0;
    _recordedResultDecisions.clear();
    _batchNarrationId = '';
    _lastBatchNarrationDiagnostic = '';
    _resultAllowed = true;
    _resultLossReason = null;
    _playback = null;
    _failed = false;
    _interrupted = false;
    _sealed = false;
    _spokenConfirmations.clear();
    if (_questionSession != sessionId) {
      _questionSession = sessionId;
      _spokenQuestions.clear();
    }
  }

  /// Entry presentation is not a ledger fact and is never replayed on restore.
  void speakOpening(String text, {bool restored = false}) {
    if (_openingHandled || _generation != 0 || restored || _closed) return;
    _openingHandled = true;
    if (!enabled() || text.trim().isEmpty) return;
    begin();
    _resultAllowed = false;
    _enqueue(text);
    finish();
  }

  void accept(AgentEvent event, {String commandId = ''}) {
    if (!_closed &&
        (event.sessionId.isEmpty || event.sessionId == _resultSession) &&
        (event.kind == AgentEventKind.signal ||
            event.kind == AgentEventKind.finalResponse) &&
        event.payload['type'] == 'BATCH_CALL_RESULT') {
      final batch = event.payload['batchCallResult'];
      if (batch is Map && batch['batchId'] is String) {
        _setBatchNarrationId(batch['batchId'] as String);
      }
      _recordBatchNarration(
        DiagnosticBatchResultStage.narrationTerminalSignal,
        _resultAllowed ? DiagnosticResult.received : DiagnosticResult.cancelled,
        hasResult: _waitingResult != null,
        reason: _resultAllowed
            ? null
            : _resultLossReason ??
                  DiagnosticBatchResultReason.resultEligibilityLost,
      );
    }
    if (!_closed && _resultAllowed) {
      results.terminal(event, commandId: commandId);
    }
    if (!_eligible || _sealed) return;
    final notice = event.payload['type'] == 'MEMORY_NOTICE'
        ? event.text
        : event.kind == AgentEventKind.signal
        ? MemoryNotice.prefix(event.text)
        : '';
    if (notice.isNotEmpty) {
      final key = 'memory:${event.sessionId}:$notice';
      if (!_spokenConfirmations.contains(key) && _enqueue(notice)) {
        _spokenConfirmations.add(key);
      }
      if (event.payload['type'] == 'MEMORY_NOTICE') return;
    }
    if (event.kind == AgentEventKind.text) {
      final spoken = _markdown.append(event.text);
      if (spoken.trim().isNotEmpty) _speechStart ??= ReplySpeechStart();
      _buffer += spoken;
      if (_buffer.length + _markdown.bufferedLength > 65536) {
        unawaited(interrupt());
        return;
      }
      var sentenceCompleted = false;
      while (true) {
        final end = SpeechTextPolicy.sentenceEnd(_buffer);
        if (end < 0) break;
        final sentence = _buffer.substring(0, end + 1).trim();
        _buffer = _buffer.substring(end + 1);
        _enqueue(sentence, ordinary: true);
        sentenceCompleted = true;
      }
      final canWaitForTail =
          _buffer.isNotEmpty &&
          _playback?.hasPendingText != true &&
          _playback?.synthesizing != true;
      if (sentenceCompleted || !canWaitForTail) {
        _first?.cancel();
        _first = null;
      }
      if (canWaitForTail) {
        _first ??= Timer(const Duration(milliseconds: 800), flush);
      }
    } else if (event.kind == AgentEventKind.signal ||
        event.kind == AgentEventKind.finalResponse) {
      if (event.kind == AgentEventKind.finalResponse) {
        const deniedTurn = 'membership-denial-terminal';
        if (_spokenConfirmations.contains(deniedTurn)) return;
        if (MembershipDenialReply.message(
              event.payload['errorCode'] ?? event.payload['code'],
            ) !=
            null) {
          _spokenConfirmations.add(deniedTurn);
        }
      }
      final question = event.payload['type'] == 'ASK_USER';
      String? promptKey;
      if (question || event.payload['type'] == 'MAKE_CALL_REQUEST') {
        final tool = ConversationMessages.text(
          event.payload,
          'pendingToolCallId',
        );
        if (tool.isNotEmpty) {
          promptKey =
              '${event.sessionId.isEmpty ? _questionSession : event.sessionId}:$tool';
          if ((question ? _spokenQuestions : _spokenConfirmations).contains(
            promptKey,
          )) {
            return;
          }
        }
      }
      var prompt = SpeechPromptPolicy.prompt(event);
      if (event.payload['type'] == 'TEXT_REPLY' && prompt.isNotEmpty) {
        final markdown = SpeechMarkdownStream();
        prompt = markdown.append(prompt) + markdown.finish();
      }
      if (_enqueue(prompt) && promptKey != null) {
        (question ? _spokenQuestions : _spokenConfirmations).add(promptKey);
      }
      if (event.payload['type'] == 'TEXT_REPLY') flush();
    } else if (event.kind == AgentEventKind.done) {
      finish();
    } else if (event.kind == AgentEventKind.error) {
      unawaited(interrupt());
    }
  }

  bool _enqueue(String text, {bool ordinary = false}) {
    final speakable = ordinary
        ? SpeechTextPolicy.cleanStreamingSegment(text)
        : text;
    if (!_eligible || speakable.trim().isEmpty) return false;
    final generation = _generation;
    try {
      _playback ??= factory(() => _eligible && generation == _generation, () {
        if (_closed || generation != _generation) return;
        _failed =
            _failed ||
            phase == ReplySpeechPhase.failed ||
            (_playback?.failures ?? 0) > 0;
        if (phase == ReplySpeechPhase.cancelled) _paused = true;
        if (phase == ReplySpeechPhase.cancelled ||
            phase == ReplySpeechPhase.failed) {
          if (phase == ReplySpeechPhase.failed) {
            _resultAllowed = false;
            _resultLossReason = DiagnosticBatchResultReason.playbackFailed;
            _waitingResult = null;
            results.clear();
          }
          _interrupted = true;
          _buffer = '';
          _first?.cancel();
        }
        notifyListeners();
        if (phase == ReplySpeechPhase.completed) resumeResult();
      });
      if (ordinary) {
        _speechStart?.reportTo(_playback!);
      }
      return _playback!.enqueue(speakable);
    } catch (_) {
      return false; // A failed synchronous handoff must not consume prompt identity.
    }
  }

  void flush() {
    _first?.cancel();
    _first = null;
    final remaining = _buffer.trim();
    _buffer = '';
    _enqueue(remaining, ordinary: true);
  }

  void finish() {
    if (_sealed || !_eligible) return;
    _buffer += _markdown.finish();
    flush();
    _sealed = true;
    _playback?.complete();
  }

  Future<void> interrupt() => _interrupt(
    paused: false,
    reason: DiagnosticBatchResultReason.explicitInterruption,
  );

  /// Normal external interruption stops narration only, retaining real failures.
  Future<void> pause() => _interrupt(
    paused: _paused || isActive || _buffer.isNotEmpty,
    reason: DiagnosticBatchResultReason.userStoppedSpeech,
  );

  /// Lifecycle audio cancellation is not an explicit request to mute results.
  Future<void> pauseForLifecycle() async {
    _paused = _paused || isActive || _buffer.isNotEmpty;
    await _stop();
  }

  void setForeground(bool foreground) {
    if (_foreground == foreground) return;
    _foreground = foreground;
    if (foreground) scheduleMicrotask(resumeResult);
  }

  Future<void> _interrupt({
    required bool paused,
    required DiagnosticBatchResultReason reason,
  }) async {
    _paused = paused;
    _resultAllowed = false;
    _resultLossReason = reason;
    _waitingResult = null;
    _waitingResultIdentity = null;
    results.clear();
    await _stop();
  }

  /// A call owns audio temporarily; unlike user/background cancellation this
  /// preserves the current result join, without enabling ordinary speech.
  void waitForBatch(String id) {
    _setBatchNarrationId(id);
    results.deferredBatch(id);
    _recordBatchNarration(
      DiagnosticBatchResultStage.narrationWaiting,
      DiagnosticResult.started,
      hasResult: false,
    );
    pauseForCall();
  }

  Future<void> pauseForResult() => _stop();

  void pauseForCall() {
    if (!_interrupted) unawaited(_stop());
  }

  void project(
    Iterable<LedgerEvent> facts,
    Iterable<ConversationMessage> messages,
  ) {
    results.project(facts, messages);
    try {
      _visibleResult = results.visibleResult(_resultSession, facts, messages);
    } catch (_) {
      _visibleResult = null; // Diagnostics cannot block result projection.
    }
    resumeResult();
  }

  void resumeResult() {
    if (!_foreground) return;
    final visible = _visibleResult;
    final pending = visible != null;
    if (_closed || !_resultAllowed) {
      _recordBatchNarration(
        DiagnosticBatchResultStage.narrationBlocked,
        DiagnosticResult.cancelled,
        hasResult: _waitingResult != null,
        reason: _closed
            ? DiagnosticBatchResultReason.controllerClosed
            : _resultLossReason ??
                  DiagnosticBatchResultReason.resultEligibilityLost,
      );
      if (pending) {
        _recordResult(visible, DiagnosticTtsNarrationDecision.turnInterrupted);
      }
      return;
    }
    if (!enabled()) {
      _recordBatchNarration(
        DiagnosticBatchResultStage.narrationBlocked,
        DiagnosticResult.cancelled,
        hasResult: _waitingResult != null,
        reason: DiagnosticBatchResultReason.speechDisabled,
      );
      if (pending) {
        _recordResult(visible, _safeGateDecision());
      }
      return;
    }
    if (_stopsPending > 0) return;
    if (_waitingResult == null) {
      final taken = results.takeWithMetadata();
      _waitingResult = taken?.text;
      _waitingResultIdentity = taken == null
          ? null
          : (eventId: taken.eventId, sequence: taken.sequence);
      if (taken != null) _resultHandoffRetries = 0;
    }
    if (_waitingResult == null) {
      _recordBatchNarration(
        DiagnosticBatchResultStage.narrationBlocked,
        DiagnosticResult.received,
        hasResult: false,
        reason: DiagnosticBatchResultReason.resultNotReady,
      );
      if (pending) {
        _recordResult(visible, DiagnosticTtsNarrationDecision.resultNotMatched);
      }
      return;
    }
    if (_sealed && isActive) {
      _recordBatchNarration(
        DiagnosticBatchResultStage.narrationBlocked,
        DiagnosticResult.received,
        hasResult: true,
        reason: DiagnosticBatchResultReason.audioActive,
      );
      _recordResult(
        _waitingResultIdentity,
        DiagnosticTtsNarrationDecision.previousSpeechActive,
      );
      return;
    }
    final text = _waitingResult!;
    final identity = _waitingResultIdentity;
    if (_sealed || _interrupted) {
      _playback = null;
      _sealed = false;
      _interrupted = false;
    }
    final queued = _enqueue(text);
    if (queued) {
      _paused = false;
      _waitingResult = null;
      _waitingResultIdentity = null;
      _visibleResult = null;
      _resultHandoffRetries = 0;
    } else if (_eligible && _resultHandoffRetries == 0 && !isActive) {
      // Nothing was admitted or handed to the device. Retire a rejected
      // playback before one bounded retry of this still-current result.
      _resultHandoffRetries = 1;
      final rejected = _playback;
      if (rejected != null) {
        ++_generation;
        _playback = null;
        unawaited(_retryResultAfterCancel(rejected, text, _generation));
      } else {
        final generation = _generation;
        scheduleMicrotask(() {
          if (_generation == generation && _waitingResult == text) {
            resumeResult();
          }
        });
      }
    }
    _recordBatchNarration(
      queued
          ? DiagnosticBatchResultStage.narrationHandoff
          : DiagnosticBatchResultStage.narrationBlocked,
      queued ? DiagnosticResult.succeeded : DiagnosticResult.failed,
      hasResult: true,
      reason: queued ? null : DiagnosticBatchResultReason.enqueueFailed,
    );
    if (queued) _batchNarrationId = '';
    if (identity != null) {
      _recordResult(
        identity,
        queued
            ? DiagnosticTtsNarrationDecision.queued
            : DiagnosticTtsNarrationDecision.enqueueRejected,
      );
    }
    if (queued) finish();
  }

  Future<void> _retryResultAfterCancel(
    ReplySpeechPlayback rejected,
    String text,
    int generation,
  ) async {
    try {
      await rejected.cancel();
    } catch (_) {
      if (_generation == generation && _waitingResult == text) {
        _failed = true;
        notifyListeners();
      }
      return;
    }
    if (_generation == generation && _waitingResult == text) resumeResult();
  }

  void _setBatchNarrationId(String id) {
    if (id == _batchNarrationId) return;
    _batchNarrationId = id;
    _lastBatchNarrationDiagnostic = '';
  }

  void _recordBatchNarration(
    DiagnosticBatchResultStage stage,
    DiagnosticResult result, {
    required bool hasResult,
    DiagnosticBatchResultReason? reason,
  }) {
    if (diagnostics == null || _batchNarrationId.isEmpty) return;
    final key = '${stage.name}:${reason?.name}:$hasResult';
    if (key == _lastBatchNarrationDiagnostic) return;
    _lastBatchNarrationDiagnostic = key;
    emitDiagnostic(
      diagnostics,
      DiagnosticEvent(
        operation: DiagnosticOperation.batchResultSync,
        result: result,
        sessionId: _resultSession,
        batchResult: DiagnosticBatchResultDetails(
          stage: stage,
          batchId: _batchNarrationId,
          hasResult: hasResult,
          reason: reason,
        ),
      ),
    );
  }

  DiagnosticTtsNarrationDecision _safeGateDecision() {
    try {
      return gateDecision?.call() ?? DiagnosticTtsNarrationDecision.gateClosed;
    } catch (_) {
      return DiagnosticTtsNarrationDecision.gateClosed;
    }
  }

  void _recordResult(
    ({String eventId, int sequence})? identity,
    DiagnosticTtsNarrationDecision decision,
  ) {
    if (identity == null || diagnostics == null) return;
    final key = '${identity.eventId}:${decision.name}';
    if (!_recordedResultDecisions.add(key)) return;
    while (_recordedResultDecisions.length > 128) {
      _recordedResultDecisions.remove(_recordedResultDecisions.first);
    }
    emitDiagnostic(
      diagnostics,
      DiagnosticEvent(
        operation: DiagnosticOperation.ttsNarration,
        result: decision == DiagnosticTtsNarrationDecision.queued
            ? DiagnosticResult.succeeded
            : DiagnosticResult.received,
        sessionId: _resultSession,
        ttsNarration: DiagnosticTtsNarrationDetails(
          sequence: identity.sequence,
          decision: decision,
        ),
      ),
    );
  }

  Future<void> _stop() async {
    _failed =
        _failed ||
        phase == ReplySpeechPhase.failed ||
        (_playback?.failures ?? 0) > 0;
    _interrupted = true;
    ++_generation;
    _speechStart = null;
    _first?.cancel();
    _first = null;
    _markdown.reset();
    _buffer = '';
    final old = _playback;
    if (old == null) {
      scheduleMicrotask(() {
        if (!_closed) notifyListeners();
      });
      return;
    }
    ++_stopsPending;
    var stopped = false;
    try {
      await old.cancel();
      stopped = true;
      if (!_closed && identical(old, _playback)) {
        _failed = _failed || old.phase == ReplySpeechPhase.failed;
        notifyListeners();
      }
    } finally {
      --_stopsPending;
      if (stopped &&
          _stopsPending == 0 &&
          _foreground &&
          _resultAllowed &&
          _visibleResult != null) {
        scheduleMicrotask(resumeResult);
      }
    }
  }

  @override
  void dispose() {
    _closed = true;
    unawaited(interrupt());
    super.dispose();
  }
}
