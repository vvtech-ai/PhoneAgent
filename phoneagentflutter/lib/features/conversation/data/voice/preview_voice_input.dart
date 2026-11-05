import 'dart:async';
import '../../domain/agent_protocol.dart';
import '../../domain/history/conversation_history.dart';
import '../../domain/history/ledger_event.dart';
import '../../domain/tools/conversation_permission.dart';
import '../../domain/voice/voice_gateway_event.dart';
import '../../domain/voice/voice_input_session.dart';
import 'fallback_voice_input_session.dart';

/// Explicit synthetic boundaries; never opens a socket or requests hardware.
class PreviewVoiceInput
    implements
        AgentGateway,
        ConversationHistoryRepository,
        ConversationPermissionSource {
  bool denyPermission = false;
  bool failPrimaryRecognition = false, failBackupRecognition = false;
  int fallbackStarts = 0;
  PreviewVoiceSession? latest;
  final commands = <AgentCommand>[];
  final _facts = <LedgerEvent>[];
  bool failNextCommand = false,
      commitBeforeFailure = false,
      failHistory = false;
  void recoveryScenario({bool committed = false, bool historyFails = false}) {
    failNextCommand = true;
    commitBeforeFailure = committed;
    failHistory = historyFails;
  }

  VoiceInputSession create() => FallbackVoiceInputSession(
    primary: latest = PreviewVoiceSession(fail: failPrimaryRecognition),
    createFallback: () {
      fallbackStarts++;
      return latest = PreviewVoiceSession(fail: failBackupRecognition);
    },
    fallbackEndpoint: Uri.parse('wss://synthetic.invalid/transcription'),
    isCurrent: () => true, // Controller owns preview page cancellation.
  );
  @override
  Future<PermissionGrant> resolve(
    ConversationPermission permission, {
    required bool request,
  }) async => denyPermission ? PermissionGrant.denied : PermissionGrant.granted;
  @override
  AgentRun start(AgentCommand command) {
    commands.add(command);
    void fact(String type, String owner, Map<String, Object?> payload) {
      _facts.add(
        LedgerEvent(
          eventId: 'mock-${_facts.length + 1}',
          sessionId: command.sessionId,
          sequence: _facts.length + 1,
          type: type,
          schemaVersion: 1,
          commandId: owner,
          payload: payload,
        ),
      );
    }

    if (command.supersedesCommandId case final original?) {
      fact('RUN_CANCELLED', original, {'stage': 'recovery_revision'});
    }
    fact('USER_TURN_ACCEPTED', command.commandId, {
      'text': command.message ?? '',
    });
    const reply = 'MOCK：已收到输入，可继续文字或按住说话。';
    final failure = failNextCommand;
    failNextCommand = false;
    if (!failure || commitBeforeFailure) {
      fact('ASSISTANT_TURN_COMMITTED', command.commandId, {'text': reply});
    }
    if (failure) {
      return AgentRun(Stream.error(AgentTransportFailure.network), () {});
    }
    return AgentRun(
      Stream.fromIterable([
        AgentEvent(
          AgentEventKind.finalResponse,
          sessionId: command.sessionId,
          text: reply,
          payload: const {'type': 'TEXT_REPLY'},
        ),
        const AgentEvent(AgentEventKind.done),
      ]),
      () {},
    );
  }

  @override
  Future<RestoredConversation> restore(String sessionId) async {
    if (failHistory) throw StateError('Synthetic history failure');
    return RestoredConversation(
      ConversationDetail(sessionId: sessionId, title: 'MOCK', status: 'CLOSED'),
      ledger: LedgerSnapshot(
        sessionId,
        _facts.length,
        LedgerProjection(
          status: 'OPEN',
          continuable: true,
          pendingRestorable: false,
          migrationStatus: 'READY',
          projectedThrough: _facts.length,
        ),
        List.of(_facts),
      ),
    );
  }
}

class PreviewVoiceSession implements VoiceInputSession {
  PreviewVoiceSession({this.fail = false});
  final bool fail;
  final _events = StreamController<VoiceGatewayEvent>();
  Timer? _partial;
  bool _closed = false;
  @override
  Stream<VoiceGatewayEvent> get events => _events.stream;
  @override
  Future<void> start(Uri endpoint) async {
    if (_closed) return;
    _events.add(const VoiceReady());
    _partial = Timer(
      const Duration(milliseconds: 350),
      () => emit(
        fail
            ? const VoiceGatewayFailure('provider_error')
            : const VoiceTranscript('帮我整理明天的安排', isFinal: false),
      ),
    );
  }

  void emit(VoiceGatewayEvent event) {
    if (!_closed) _events.add(event);
  }

  @override
  Future<void> release() async {
    _partial?.cancel();
  }

  @override
  Future<void> cancel() async {
    if (_closed) return;
    _closed = true;
    _partial?.cancel();
    unawaited(_events.close());
  }
}
