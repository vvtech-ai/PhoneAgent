import 'confirmation_supplement.dart';

/// Pending display records only. Task/tool state remains owned by the ledger.
class ConfirmationSupplementOutbox {
  ConfirmationSupplementOutbox({
    required this.sessionId,
    required this.store,
    required this.repository,
    required this.onRecords,
  });
  final String sessionId;
  final ConfirmationSupplementStore store;
  final ConfirmationSupplementRepository repository;
  final void Function(List<ConfirmationSupplement>, bool failed) onRecords;
  final Map<String, ConfirmationSupplement> _pending = {};
  Future<void> _writes = Future<void>.value();
  bool _closed = false, _flushing = false;
  bool saveFailed = false;

  Future<void> restore() async {
    try {
      final records = await store.read();
      if (_closed) return;
      for (final record in records) {
        _pending.putIfAbsent(record.id, () => record);
      }
      _publish();
      await flush();
    } catch (_) {
      if (!_closed) {
        saveFailed = true;
        _publish();
      }
    }
  }

  Future<void> add(ConfirmationSupplement record) async {
    if (_closed || _pending.containsKey(record.id)) return;
    _pending[record.id] = record;
    _publish();
    try {
      await _persist();
    } catch (_) {
      if (!_closed) {
        saveFailed = true;
        _publish();
      }
      return;
    }
    await flush();
  }

  Future<void> flush() async {
    if (_closed || _flushing) return;
    _flushing = true;
    try {
      await _persist();
      while (!_closed && _pending.isNotEmpty) {
        final record = _pending.values.first;
        await repository.save(sessionId, record);
        if (_closed) return;
        _pending.remove(record.id);
        try {
          await _persist();
        } catch (_) {
          _pending[record.id] = record;
          rethrow;
        }
      }
      saveFailed = false;
    } catch (_) {
      saveFailed = true;
    } finally {
      _flushing = false;
      if (!_closed) _publish();
    }
  }

  Future<void> _persist() {
    final records = List<ConfirmationSupplement>.of(_pending.values);
    final operation = _writes
        .catchError((_) {})
        .then((_) => store.write(records));
    _writes = operation;
    return operation;
  }

  void _publish() => onRecords(List.unmodifiable(_pending.values), saveFailed);
  void close() {
    _closed = true;
  }
}
