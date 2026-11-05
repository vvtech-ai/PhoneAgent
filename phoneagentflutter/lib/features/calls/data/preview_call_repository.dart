import '../domain/call_session.dart';

/// Deliberate synthetic port. Never obtains an account, ticket or phone number.
class PreviewCallRepository implements CallSessionRepository {
  bool failPoll = false, failHangup = false;
  int hangupRequests = 0;
  String callState = 'DIALING', dialogue = '', mode = '';
  int revision = 0;
  CallSessionSnapshot get snapshot => CallSessionSnapshot(
    callId: 'mock-call',
    taskId: 'mock-conversation',
    callState: callState,
    targetName: '演练门店',
    phoneNumber: '010-00000000',
    dialogueDetail: dialogue,
    handoffMode: mode,
    updatedAt: DateTime.utc(
      2026,
      1,
      1,
    ).add(Duration(seconds: revision)).toIso8601String(),
  );
  void connected() {
    callState = 'CONNECTED';
    revision++;
  }

  void append() {
    dialogue +=
        '${dialogue.isEmpty ? '' : '\n'}assistant: 你好，这是合成对话。\ncallee: 好的，这是演练回复。';
    revision++;
  }

  void end() {
    callState = 'ENDED';
    mode = 'COMPLETED';
    revision++;
  }

  @override
  Future<CallSessionSnapshot> status(CallSessionTarget target) async {
    if (failPoll) throw StateError('synthetic polling failure');
    return snapshot;
  }

  @override
  Future<CallSessionSnapshot> hangUp(CallSessionTarget target) async {
    hangupRequests++;
    if (failHangup) {
      failHangup = false;
      throw StateError('synthetic hangup failure');
    }
    end();
    return snapshot;
  }

  @override
  Future<CallMonitorTicket> monitorTicket(CallSessionTarget target) =>
      Future.error(
        UnsupportedError('Preview never requests media credentials'),
      );
}
