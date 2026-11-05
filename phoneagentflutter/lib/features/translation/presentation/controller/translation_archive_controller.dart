import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/translation_archive.dart';

class TranslationArchiveStatus {
  const TranslationArchiveStatus({
    this.busy = false,
    this.pending = 0,
    this.failed = false,
    this.completed = 0,
  });
  final bool busy, failed;
  final int pending, completed;
}

/// Account lifetime, independent of navigation and media. Never replays calls.
class TranslationArchiveController
    extends StateNotifier<TranslationArchiveStatus> {
  TranslationArchiveController({
    required this.accountId,
    required this.store,
    required this.gateway,
    required this.isCurrent,
    this.onCompleted,
    this.onFailure,
    this.prepareRecoveredRecording,
    this.removeArchivedRecording,
    this.drainDuration = const Duration(milliseconds: 500),
  }) : super(const TranslationArchiveStatus());
  final String accountId;
  final TranslationArchiveStore? store;
  final TranslationArchiveGateway? gateway;
  final bool Function() isCurrent;
  final void Function(String clientCallId, String callId)? onCompleted;
  final Duration drainDuration;
  final void Function(String stage, Object error)? onFailure;
  final Future<TranslationArchiveEntry> Function(TranslationArchiveEntry)?
  prepareRecoveredRecording;
  final Future<void> Function(TranslationArchiveEntry)? removeArchivedRecording;
  final _entries = <String, TranslationArchiveEntry>{};
  final _seals = <String, Timer>{};
  final _live = <String>{}, _done = <String>{}, _failed = <String>{};
  Future<void> _tail = Future<void>.value();
  bool _loaded = false, _storageFailed = false;
  int _completed = 0;
  bool get _current =>
      mounted && store != null && gateway != null && isCurrent();
  TranslationArchiveStatus get snapshot => state;
  Future<void> get idle => _tail;

  void observe(TranslationArchiveEntry entry) {
    if (!_current ||
        entry.accountId != accountId ||
        _done.contains(entry.clientCallId)) {
      return;
    }
    final id = entry.clientCallId;
    _live.add(id);
    final previous = _entries[id];
    final merged = _entries[id] = previous?.merge(entry) ?? entry;
    final recordingFinished =
        previous?.recordingPending == true && !merged.recordingPending;
    if (merged.stage == TranslationArchiveStage.draining &&
        !merged.recordingPending &&
        merged.endedAt != null &&
        merged.connectedAt != null &&
        !_seals.containsKey(id)) {
      _seals[id] = Timer(drainDuration, () {
        _queue(() async {
          _seals.remove(id);
          final current = _entries[id];
          if (current == null) return;
          // Terminal state must survive an unavailable journal read. Retry
          // persists this same sealed snapshot before making any request.
          _entries[id] = current.seal();
          await _load();
          await _save();
          await _archive(id);
        });
      });
    }
    _queue(() async {
      if (entry.connectedAt == null &&
          entry.stage != TranslationArchiveStage.active) {
        _entries.remove(id);
        _rememberDone(id);
      }
      await _load();
      await _save();
      // Legacy journals may already be sealed while waiting for recording.
      if (recordingFinished &&
          _entries[id]?.stage == TranslationArchiveStage.ready) {
        await _archive(id);
      }
    });
  }

  Future<void> recover() => _queue(() async {
    await _load();
    _recoverStored();
    await _save();
    await _retryReady();
  });

  void _recoverStored() {
    for (final entry in _entries.values.toList()) {
      if (_live.contains(entry.clientCallId)) continue;
      if (entry.connectedAt == null) {
        _entries.remove(entry.clientCallId);
        _rememberDone(entry.clientCallId);
      } else {
        _entries[entry.clientCallId] = entry.recover();
      }
    }
  }

  Future<void> retry() => _queue(() async {
    await _load();
    _recoverStored();
    await _save();
    await _retryReady();
  });

  Future<void> _load() async {
    if (_loaded) return;
    final saved = await store!.load();
    _guard();
    for (final entry in saved) {
      if (entry.accountId != accountId) {
        throw StateError('Archive owner mismatch');
      }
      if (!_done.contains(entry.clientCallId)) {
        _entries.putIfAbsent(entry.clientCallId, () => entry);
      }
    }
    _loaded = true;
  }

  Future<void> _save() async {
    _guard();
    await store!.save(_entries.values.toList());
    _guard();
    _storageFailed = false;
  }

  Future<void> _retryReady() async {
    for (final id in _entries.keys.toList()) {
      _guard();
      if (_entries[id]?.canArchive == true) {
        await _archive(id);
      }
    }
  }

  Future<void> _archive(String id) async {
    var entry = _entries[id];
    if (entry == null || !entry.canArchive) return;
    _guard();
    var failureStage = 'archiveCreate';
    try {
      final prepare = prepareRecoveredRecording;
      if (entry.recordingPending && !_live.contains(id) && prepare != null) {
        failureStage = 'recordingRecovery';
        final prepared = await prepare(entry);
        _guard();
        entry = entry.merge(prepared);
        _entries[id] = entry;
        await _save();
      }
      // Live encoding is normal waiting, not a failed request.
      if (entry.recordingPending) return;
      final gateway = this.gateway!;
      if (entry.stage == TranslationArchiveStage.ready) {
        failureStage = 'archiveCreate';
        final callId = gateway is TranslationArchivePhasedGateway
            ? await gateway.createRecord(entry)
            : await gateway.archive(entry);
        _guard();
        entry = entry.copy(
          serverCallId: callId,
          stage:
              gateway is TranslationArchivePhasedGateway &&
                  entry.route == TranslationArchiveRoute.domesticSip
              ? TranslationArchiveStage.recordingUpload
              : TranslationArchiveStage.completed,
        );
        _entries[id] = entry;
        failureStage = 'archiveStorage';
        await _save();
      }
      if (entry.stage == TranslationArchiveStage.recordingUpload) {
        failureStage = 'archiveStorage';
        // A failed checkpoint save must be retried before any upload.
        await _save();
        if (gateway is! TranslationArchivePhasedGateway) {
          throw StateError('Recording archive gateway unavailable');
        }
        failureStage = 'recordingUpload';
        await gateway.uploadRecording(entry, entry.serverCallId!);
        _guard();
        entry = entry.copy(stage: TranslationArchiveStage.completed);
        _entries[id] = entry;
        failureStage = 'archiveStorage';
        await _save();
      }
      final callId = entry.serverCallId!;
      failureStage = 'archiveStorage';
      _entries.remove(id);
      try {
        await _save();
      } catch (_) {
        _entries[id] = entry;
        rethrow;
      }
      _failed.remove(id);
      _rememberDone(id);
      _completed++;
      // This runs only after pending removal is durable. Cleanup failure must
      // never restore pending or replay an already completed remote upload.
      if (entry.route == TranslationArchiveRoute.domesticSip &&
          entry.recording != null) {
        try {
          await removeArchivedRecording?.call(entry);
        } catch (_) {
          /* keep residual files; archive remains committed */
        }
      }
      // Refresh is not part of the transaction; failure must not replay PUT.
      try {
        if (_current) onCompleted?.call(id, callId);
      } catch (_) {
        /* isolated */
      }
    } catch (error) {
      if (_current) {
        _failed.add(id);
        _reportFailure(failureStage, error);
      }
    }
  }

  void _reportFailure(String stage, Object error) {
    try {
      onFailure?.call(stage, error);
    } catch (_) {
      /* Diagnostics are isolated. */
    }
  }

  void _rememberDone(String id) {
    _live.remove(id);
    _failed.remove(id);
    _done.add(id);
    if (_done.length > 256) _done.remove(_done.first);
  }

  Future<void> _queue(Future<void> Function() action) {
    final next = _tail.then((_) async {
      if (!_current) return;
      _publish(true);
      try {
        await action();
      } catch (error) {
        _storageFailed = true;
        _reportFailure('archiveStorage', error);
      }
      if (_current) _publish(false);
    });
    _tail = next;
    return next;
  }

  void _publish(bool busy) {
    if (!_current) return;
    state = TranslationArchiveStatus(
      busy: busy,
      pending: _entries.length,
      failed: _storageFailed || _failed.isNotEmpty,
      completed: _completed,
    );
  }

  void _guard() {
    if (!_current) throw StateError('Archive owner changed');
  }

  @override
  void dispose() {
    for (final timer in _seals.values) {
      timer.cancel();
    }
    _seals.clear();
    super.dispose();
  }
}
