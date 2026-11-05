import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../dialer/domain/app_call_record_repository.dart';
import '../../../dialer/domain/dial_recent_call.dart';
import '../../domain/translation_call_finished.dart';

class TranslationRecordSaveState {
  const TranslationRecordSaveState({this.saving = false, this.failedCount = 0});
  final bool saving;
  final int failedCount;
  String get error => failedCount == 0 ? '' : '本机翻译通话记录保存失败，可重试';
}

/// Account-owned, outlives a call route. Never retries remote call or billing.
class TranslationFinishedRecorder
    extends StateNotifier<TranslationRecordSaveState> {
  TranslationFinishedRecorder({
    required this.accountId,
    required this.repository,
    required this.isCurrent,
  }) : super(const TranslationRecordSaveState());
  final String accountId;
  final AppCallRecordRepository? repository;
  final bool Function() isCurrent;
  final _pending = <String, DialRecentCall>{};
  final _queued = <String>{}, _failed = <String>{}, _saved = <String>{};
  Future<void>? _work;
  TranslationRecordSaveState get snapshot => state;
  bool get available =>
      mounted && repository != null && accountId.isNotEmpty && isCurrent();
  bool get _current => available;
  Future<void> get idle async {
    while (_work != null) {
      await _work;
    }
  }

  void accept(TranslationCallFinished finished) {
    final id = finished.context.clientCallId;
    if (!_current ||
        finished.accountId != accountId ||
        id.trim().isEmpty ||
        _saved.contains(id) ||
        _pending.containsKey(id)) {
      return;
    }
    _pending[id] = finished.record;
    _queued.add(id);
    _start();
  }

  Future<void> retry() {
    if (!_current) return Future.value();
    if (_work != null) return idle;
    _queued.addAll(_failed);
    return _start();
  }

  Future<void> _start() {
    if (_work != null) return _work!;
    final done = Completer<void>();
    _work = done.future;
    scheduleMicrotask(() async {
      try {
        await _drain();
      } finally {
        _work = null;
        if (_current && _queued.isNotEmpty) unawaited(_start());
        done.complete();
      }
    });
    return done.future;
  }

  Future<void> _drain() async {
    while (_current && _queued.isNotEmpty) {
      final id = _queued.first;
      _queued.remove(id);
      final record = _pending[id];
      if (record == null) continue;
      state = TranslationRecordSaveState(
        saving: true,
        failedCount: _failed.length,
      );
      try {
        await repository!.append(record);
        if (!_current) return;
        _pending.remove(id);
        _failed.remove(id);
        _saved.add(id);
        while (_saved.length > 128) {
          _saved.remove(_saved.first);
        }
      } catch (_) {
        if (!_current) return;
        _failed.add(id);
      }
    }
    if (_current) {
      state = TranslationRecordSaveState(failedCount: _failed.length);
    }
  }

  @override
  void dispose() {
    _pending.clear();
    _queued.clear();
    _failed.clear();
    _saved.clear();
    super.dispose();
  }
}
