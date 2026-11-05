import 'dart:async';
import 'dart:convert';
import '../domain/agent_protocol.dart';
import '../domain/history/conversation_history.dart';
import '../domain/history/ledger_event.dart';
import 'stream/agent_event_decoder.dart';
import 'stream/sse_frame_decoder.dart';

/// Synthetic wire events only. No account, network, phone or payment ports.
class PreviewBatchStream
    implements AgentGateway, ConversationHistoryRepository {
  StreamController<AgentEvent>? _events;
  AgentCommand? _command;
  bool completed = false;
  int _stage = 0;
  @override
  AgentRun start(AgentCommand command) {
    _command = command;
    completed = false;
    _stage = 0;
    final events = StreamController<AgentEvent>();
    _events = events;
    events.onListen = () {
      _emit('tool_call_start', {'name': 'makeBatchCalls'});
      advance();
    };
    return AgentRun(events.stream, () {
      if (!events.isClosed) unawaited(events.close());
    });
  }

  void advance() {
    if (completed || _events == null || _events!.isClosed) return;
    _stage++;
    final index = ((_stage - 1) ~/ 2 + 1).clamp(1, 3);
    _emit('call_status_changed', {
      'sessionId': _command!.sessionId,
      'displayMessage': '合成第 $index 路状态',
      'data': {
        'batchId': 'mock-batch',
        'itemIndex': index,
        'total': 3,
        'targetName': '合成联系人$index',
        'progressOnly': true,
        'status': _stage.isOdd
            ? 'CALLING'
            : index == 2
            ? 'FAILED'
            : 'SUCCESS',
      },
    });
  }

  Map<String, Object?> get result => {
    'batchId': 'mock-batch',
    'status': 'COMPLETED',
    'totalCount': 3,
    'headline': '合成批量已汇总，无真实电话或费用',
    'items': [
      for (var i = 1; i <= 3; i++)
        {
          'itemId': 'mock-item-$i',
          'targetName': '合成联系人$i',
          'status': i == 2 ? 'FAILED' : 'SUCCESS',
          'headline': i == 2 ? '合成未接通' : '合成任务完成',
          'detail': '仅用于交互演练',
          'transcript': i == 2 ? '' : 'AI：这是合成测试。\n对方：已确认。',
        },
    ],
  };

  void finish() {
    if (_events == null || _events!.isClosed) return;
    completed = true;
    _emit('task_completed', {
      'sessionId': _command!.sessionId,
      'displayMessage': '合成结果已同步',
      'data': {'batchCallResult': result},
    });
    _events!.add(const AgentEvent(AgentEventKind.done));
  }

  void fail() => _events?.addError(AgentTransportFailure.network);
  void _emit(String type, Map<String, Object?> data) {
    if (_events?.isClosed != false) return;
    _events!.add(
      const AgentEventDecoder().decode(SseFrame(type, jsonEncode(data))),
    );
  }

  @override
  Future<RestoredConversation> restore(String sessionId) async =>
      RestoredConversation(
        ConversationDetail(
          sessionId: sessionId,
          title: '合成批量',
          status: completed ? 'COMPLETED' : 'RUNNING',
        ),
        ledger: LedgerSnapshot(
          sessionId,
          completed ? 1 : 0,
          LedgerProjection(
            status: completed ? 'COMPLETED' : 'RUNNING',
            continuable: true,
            pendingRestorable: false,
            migrationStatus: 'READY',
            projectedThrough: completed ? 1 : 0,
          ),
          [
            if (completed)
              LedgerEvent(
                eventId: 'mock-final',
                sessionId: sessionId,
                sequence: 1,
                type: 'ASSISTANT_TURN_COMMITTED',
                schemaVersion: 1,
                commandId: _command?.commandId,
                payload: {'text': '合成持久历史', 'batchCallResult': result},
              ),
          ],
        ),
      );
  void close() {
    final events = _events;
    if (events != null && !events.isClosed) unawaited(events.close());
  }
}
