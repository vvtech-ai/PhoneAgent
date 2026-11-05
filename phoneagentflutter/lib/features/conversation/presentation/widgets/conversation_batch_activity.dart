import '../controller/conversation_state.dart';

enum _BatchActivity { none, running, checking, awaitingResult, unconfirmed }

/// Read-only presentation of existing progress; owns no execution or recovery.
class ConversationBatchActivity {
  const ConversationBatchActivity._(this._activity);
  final _BatchActivity _activity;

  factory ConversationBatchActivity.from(ConversationState state) {
    if (state.phase != ConversationPhase.ready &&
        state.phase != ConversationPhase.sending) {
      return const ConversationBatchActivity._(_BatchActivity.none);
    }
    for (final message in state.messages.reversed) {
      final batch = message.batchReceipt;
      if (!message.transient || batch == null || !batch.isRunning) continue;
      if (batch.status.trim().toUpperCase() == 'VERIFYING') {
        return const ConversationBatchActivity._(_BatchActivity.unconfirmed);
      }
      if (batch.totalCount > 0 && batch.completedCount >= batch.totalCount) {
        return const ConversationBatchActivity._(_BatchActivity.awaitingResult);
      }
      if (batch.items.any(
        (item) => item.status.trim().toUpperCase() == 'VERIFYING',
      )) {
        return const ConversationBatchActivity._(_BatchActivity.checking);
      }
      return const ConversationBatchActivity._(_BatchActivity.running);
    }
    return const ConversationBatchActivity._(_BatchActivity.none);
  }

  bool get active => _activity != _BatchActivity.none;
  bool get processing => _activity != _BatchActivity.unconfirmed;
  bool get awaitingResult => _activity == _BatchActivity.awaitingResult;
  bool get priorityStatus => active && _activity != _BatchActivity.running;

  String get status => switch (_activity) {
    _BatchActivity.none => '',
    _BatchActivity.running => '正在执行多路外呼…',
    _BatchActivity.checking => '正在核对拨号状态',
    _BatchActivity.awaitingResult => '正在整理通话结果',
    _BatchActivity.unconfirmed => '结果待核对',
  };

  String get detail => switch (_activity) {
    _BatchActivity.running => '正在执行多路外呼，完成后会汇总结果',
    _BatchActivity.unconfirmed => '结果尚未确认，请稍后同步',
    _ => status,
  };
}
