import '../agent_protocol.dart';
import 'batch_receipt.dart';
import 'call_receipt.dart';
import 'batch_progress_order.dart';

/// v65 progress is a provisional snapshot, never a persisted call outcome.
class BatchProgressTracker {
  String _command = '', _batchId = '';
  int _total = 0;
  bool active = false;
  bool _uncertain = false;
  bool _freshProgressRead = false;
  bool get uncertain => _uncertain;
  String _finishedCommand = '';
  final Set<String> _finishedBatches = {};
  final Map<int, Map<String, Object?>> _items = {};
  final _order = BatchProgressOrder();
  String get batchId => _batchId;
  bool completed(String id) => _finishedBatches.contains(id);
  bool get awaitingAggregate =>
      active &&
      _total > 0 &&
      _items.length == _total &&
      _items.entries.every(
        (entry) =>
            _order.finished(
              entry.key,
              ReceiptValues.text(entry.value, 'callAttemptId'),
            ) &&
            !running(ReceiptValues.text(entry.value, 'status')),
      );
  String get command => _command;

  bool accept(AgentEvent event, String command) {
    if (command == _finishedCommand) return false;
    if (event.kind == AgentEventKind.toolStart &&
        ReceiptValues.text(event.payload, 'name').toLowerCase() ==
            'makebatchcalls') {
      _mark(command, '', 0);
      return true;
    }
    if (event.kind != AgentEventKind.status) {
      return false;
    }
    final data = event.payload;
    final batch = ReceiptValues.text(data, 'batchId').trim();
    if (batch.isNotEmpty && _finishedBatches.contains(batch)) return false;
    int number(String key) => int.tryParse('${data[key]}') ?? 0;
    final index = number('itemIndex'), total = number('total');
    if (!(active &&
            _command == command &&
            (data['progressOnly'] == true || data['progressOnly'] == 'true')) &&
        batch.isEmpty &&
        index <= 0 &&
        total <= 0) {
      return false;
    }
    _mark(command, batch, total);
    if (index > 0) {
      if (!_order.accept(index, data)) return false;
      final previous = _items[index];
      final rawStatus = BatchProgressOrder.status(data);
      final normalized = normalize(rawStatus);
      final physicalEvidence =
          ReceiptValues.text(data, 'callAttemptId').trim().isNotEmpty &&
          const {
            'SDK_STATUS',
            'PRIMARY_CLOSED',
            'STOP_ACCEPTED',
            'PHYSICAL_TERMINAL',
          }.contains(
            ReceiptValues.text(data, 'evidenceLevel').trim().toUpperCase(),
          );
      final status = _uncertain && running(normalized) && !physicalEvidence
          ? 'VERIFYING'
          : normalized;
      final text = event.text.trim().isNotEmpty
          ? event.text.trim()
          : ReceiptValues.text(data, 'message').trim();
      final retryNotStarted =
          number('attemptNumber') > 1 &&
          ReceiptValues.text(data, 'phase') == 'FAILED' &&
          ReceiptValues.text(data, 'evidenceLevel') == 'ADMISSION';
      final recalled = retryNotStarted
          ? false
          : previous?['recalled'] == true ||
                status == 'RECALLING' ||
                text.contains('重拨') ||
                text.contains('回拨');
      String field(String key) => ReceiptValues.text(data, key).isNotEmpty
          ? ReceiptValues.text(data, key)
          : ReceiptValues.text(previous ?? {}, key);
      _items[index] = {
        ...?previous,
        'itemId': previous?['itemId'] ?? 'progress_${batch}_$index',
        'targetName': field('targetName'),
        'phoneNumber': field('phoneNumber'),
        'status': status,
        'headline': headline(
          status == 'VERIFYING' ? status : rawStatus.toUpperCase(),
        ),
        'detail': status == 'VERIFYING'
            ? '尚未取得该路是否实际拨出的证据，请稍后刷新。'
            : text.isEmpty
            ? headline(rawStatus.toUpperCase())
            : text,
        if (data['callAttemptId'] != null)
          'callAttemptId': data['callAttemptId'],
        'attemptCount': recalled ? 2 : 1,
        'recalled': recalled,
        'abnormal':
            status == 'FAILED' || status == 'USER_CANCELLED' || running(status),
      };
    }
    return true;
  }

  void _mark(String command, String batch, int total) {
    if (_command != command ||
        (batch.isNotEmpty && _batchId.isNotEmpty && batch != _batchId)) {
      clear();
    }
    _command = command;
    if (batch.isNotEmpty) _batchId = batch;
    if (total > _total) _total = total;
    active = true;
  }

  BatchReceipt? snapshot({bool failed = false, bool unconfirmed = false}) {
    if (_items.isEmpty) return null;
    final keys = _items.keys.toList()..sort();
    final items = [
      for (final key in keys) {..._items[key]!},
    ];
    final total = _total > items.length ? _total : items.length;
    final finished = items.where((i) => !running('${i['status']}')).length;
    if (failed) {
      for (final item in items) {
        if (!running('${item['status']}')) continue;
        item.addAll({
          'status': 'FAILED',
          'headline': '结果未完整返回',
          'detail': '通话已结束，但该路结果未完整返回，请稍后刷新确认。',
          'abnormal': true,
        });
      }
    }
    if (unconfirmed) {
      for (final item in items) {
        if (!running('${item['status']}')) continue;
        item.addAll({
          'status': 'VERIFYING',
          'headline': '结果待核对',
          'detail': '尚未取得该路最终结果，请稍后重新进入会话核对。',
          'abnormal': true,
        });
      }
    }
    return BatchReceipt.fromJson({
      if (_batchId.isNotEmpty) 'batchId': _batchId,
      'status': failed
          ? 'FAILED'
          : unconfirmed
          ? 'VERIFYING'
          : 'RUNNING',
      'headline': unconfirmed
          ? '批量外呼结果尚未确认，请稍后重新进入会话核对'
          : failed
          ? '批量外呼已结束，部分结果未完整返回'
          : _uncertain && !_freshProgressRead
          ? '外呼请求失败，正在核对拨号状态'
          : '批量外呼进行中，$finished/$total 路已有结果',
      'totalCount': total,
      'items': items,
    }, fallbackId: 'progress:$_command');
  }

  void markUncertain() {
    _uncertain = true;
    _freshProgressRead = false;
    for (final item in _items.values) {
      if (!running('${item['status']}')) continue;
      item.addAll({
        'status': 'VERIFYING',
        'headline': '正在核对拨号状态',
        'detail': '尚未取得该路是否实际拨出的证据，请稍后刷新。',
        'abnormal': true,
      });
    }
  }

  void progressRead() {
    if (active && _uncertain) _freshProgressRead = true;
  }

  void clear() {
    active = false;
    _uncertain = false;
    _freshProgressRead = false;
    _command = _batchId = '';
    _total = 0;
    _items.clear();
    _order.clear();
  }

  /// Stop provisional updates while allowing a late final for this batch.
  void stopObserving() {
    final command = _command;
    clear();
    _finishedCommand = command;
  }

  void finish(String command, {String batchId = ''}) {
    if (_batchId.isNotEmpty) _finishedBatches.add(_batchId);
    if (batchId.isNotEmpty) _finishedBatches.add(batchId);
    clear();
    _finishedCommand = command;
  }

  static bool isFinal(AgentEvent event) {
    final carriesResult =
        (event.kind == AgentEventKind.finalResponse ||
            event.kind == AgentEventKind.signal) &&
        (event.payload['type'] == 'BATCH_CALL_RESULT' ||
            event.payload['batchCallResult'] is Map);
    if (!carriesResult) return false;
    final data = ReceiptValues.object(event.payload['batchCallResult']);
    if (data.isEmpty) return false;
    final receipt = BatchReceipt.fromJson(data, fallbackId: '');
    return !receipt.isRunning &&
        (receipt.explicitId.isNotEmpty ||
            receipt.isExecutionError && receipt.items.isEmpty);
  }

  static bool running(String status) => const {
    'STARTED',
    'CALLING',
    'RECALLING',
    'RUNNING',
    'LINE_BUSY_WAITING',
    'WAITING_FOR_LINE',
    'WAITING_CALL',
    'VERIFYING',
  }.contains(status);

  static String normalize(String raw) => switch (raw.trim().toUpperCase()) {
    'SUCCESS' || 'ACCEPTED' || 'CONFIRMED' => 'SUCCESS',
    'FAILED' ||
    'FAIL' ||
    'ERROR' ||
    'DECLINED' ||
    'REJECTED' ||
    'REFUSED' ||
    'MISSED' ||
    'MISSED_CALL' ||
    'NO_ANSWER' ||
    'NOANSWER' ||
    'TIMEOUT' ||
    'HUNG_UP' ||
    'HANG_UP' ||
    'HANGUP' => 'FAILED',
    'USER_CANCELLED' ||
    'USER_CANCELED' ||
    'CANCELLED' ||
    'CANCELED' => 'USER_CANCELLED',
    'ABNORMAL' || 'PENDING' || '' => 'UNCLEAR',
    'RECALLING' || 'RETRYING' || 'REDIALING' => 'RECALLING',
    'LINE_BUSY_WAITING' || 'WAITING_FOR_LINE' => 'LINE_BUSY_WAITING',
    'WAITING_CALL' => 'WAITING_CALL',
    'CALLING' ||
    'DIALING' ||
    'RINGING' ||
    'CONNECTED' ||
    'ENDING' ||
    'CANCELLING' ||
    'ENDED' ||
    'STOP_ACCEPTED' ||
    'PRIMARY_CLOSED_FORK_OBSERVING' ||
    'PHYSICAL_CLOSED' ||
    'RESULT_PENDING' => 'CALLING',
    final other => other,
  };
  static String headline(String status) => switch (status) {
    'FAILED' => '未完成',
    'USER_CANCELLED' => '已取消',
    'NEEDS_RECALL' => '需重拨',
    'RECALLING' => '正在重拨',
    'LINE_BUSY_WAITING' || 'WAITING_CALL' => '等待呼叫中',
    'RINGING' => '正在振铃，等待接听',
    'CONNECTED' => '正在通话',
    'ENDING' || 'PHYSICAL_CLOSED' || 'RESULT_PENDING' => '正在整理通话结果',
    'CANCELLING' ||
    'STOP_ACCEPTED' ||
    'PRIMARY_CLOSED_FORK_OBSERVING' => '正在确认通话状态',
    'VERIFYING' => '正在核对拨号状态',
    'CALLING' || 'STARTED' || 'REQUESTED' => '正在拨打',
    'UNCLEAR' || 'PENDING' || 'ABNORMAL' || '' => '结果确认中',
    _ => '结果待确认',
  };
}
