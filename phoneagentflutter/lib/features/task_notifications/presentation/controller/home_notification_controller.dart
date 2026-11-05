import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../tasks/domain/task_records.dart';
import '../../domain/home_notification.dart';

class HomeNotificationState {
  const HomeNotificationState({
    this.candidates = const [],
    this.readAtMillis = const {},
    this.ready = false,
    this.loading = false,
    this.saving = false,
    this.notice = '',
  });
  final List<HomeNotification> candidates;
  final Map<String, int> readAtMillis;
  final bool ready, loading, saving;
  final String notice;
  List<HomeNotification> get pending =>
      ready ? pendingHomeNotifications(candidates, readAtMillis) : const [];
}

class HomeNotificationController extends StateNotifier<HomeNotificationState> {
  HomeNotificationController(
    this.store, {
    required this.isCurrent,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now,
       super(const HomeNotificationState());
  final HomeNotificationReadStore store;
  final bool Function() isCurrent;
  final DateTime Function() now;
  Future<void> _writes = Future.value();
  final _queuedIds = <String>{};
  final _failedReadIds = <String>{};
  var _writeCount = 0, _readGeneration = 0;
  bool _closed = false;
  bool get _current => mounted && !_closed && isCurrent();
  Set<String> get _protected => state.candidates.map((item) => item.id).toSet();

  void replaceRecords(List<TaskRecord> records) {
    if (_current) {
      _publish(candidates: homeNotificationCandidates(records, now: now()));
    }
  }

  Future<void> load() async {
    if (!_current || state.loading || _writeCount > 0) return;
    final generation = ++_readGeneration;
    _publish(loading: true, notice: '');
    try {
      final entries = await store.load();
      if (!_current || generation != _readGeneration) return;
      _failedReadIds.removeWhere(entries.containsKey);
      _publish(
        readAtMillis: pruneHomeNotificationReads(
          entries,
          _protected,
          now().millisecondsSinceEpoch,
        ),
        ready: true,
        loading: false,
      );
    } catch (_) {
      if (_current && generation == _readGeneration) {
        _publish(loading: false, notice: '通知读取失败，请重试');
      }
    }
  }

  Future<void> retryStorage() =>
      _failedReadIds.isEmpty ? load() : markRead(_failedReadIds.toList());

  Future<void> markAllPendingRead() =>
      markRead(state.pending.map((item) => item.id));

  Future<void> dismissCurrent() =>
      markRead(state.pending.take(1).map((item) => item.id));

  Future<void> markTaskRead({
    String? sessionId,
    String? taskId,
    String? translationCallId,
  }) => markRead([
    if (sessionId?.trim().isNotEmpty == true)
      'conversation:${sessionId!.trim()}',
    if (taskId?.trim().isNotEmpty == true) 'legacy_task:${taskId!.trim()}',
    if (translationCallId?.trim().isNotEmpty == true)
      'realtime_translation_call:${translationCallId!.trim()}',
  ]);

  Future<void> markRead(Iterable<String> requested) {
    if (!_current || !state.ready) return Future.value();
    final ids = requested
        .where(
          (id) =>
              id.isNotEmpty &&
              !state.readAtMillis.containsKey(id) &&
              !_queuedIds.contains(id),
        )
        .toSet();
    if (ids.isEmpty) return _writes;
    _queuedIds.addAll(ids);
    _writeCount++;
    _publish(saving: true, notice: '');
    _writes = _writes.then((_) async {
      try {
        if (!_current) return;
        final timestamp = now().millisecondsSinceEpoch;
        final next = pruneHomeNotificationReads(
          {...state.readAtMillis, for (final id in ids) id: timestamp},
          _protected,
          timestamp,
        );
        await store.save(next);
        if (_current) {
          _failedReadIds.removeAll(ids);
          _publish(
            readAtMillis: next,
            notice: _failedReadIds.isEmpty ? '' : '通知已读状态保存失败，请重试',
          );
        }
      } catch (_) {
        if (_current) {
          _failedReadIds.addAll(ids);
          _publish(notice: '通知已读状态保存失败，请重试');
        }
      } finally {
        _queuedIds.removeAll(ids);
        _writeCount--;
        if (_current) _publish(saving: _writeCount > 0);
      }
    });
    return _writes;
  }

  void _publish({
    List<HomeNotification>? candidates,
    Map<String, int>? readAtMillis,
    bool? ready,
    bool? loading,
    bool? saving,
    String? notice,
  }) {
    if (!_current) return;
    state = HomeNotificationState(
      candidates: candidates ?? state.candidates,
      readAtMillis: readAtMillis ?? state.readAtMillis,
      ready: ready ?? state.ready,
      loading: loading ?? state.loading,
      saving: saving ?? state.saving,
      notice: notice ?? state.notice,
    );
  }

  @override
  void dispose() {
    _closed = true;
    _readGeneration++;
    super.dispose();
  }
}
