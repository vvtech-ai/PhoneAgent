import 'diagnostic_event.dart';
import 'diagnostic_journal.dart';
import 'diagnostic_ios_crash_details.dart';
import 'diagnostic_ios_trace_details.dart';

class NativeCrashSummary {
  NativeCrashSummary.fromMap(Map<Object?, Object?> value, String scope) {
    final id = value['id'];
    final time = value['time'];
    final main = value['mainThread'];
    final kind = value['kind'];
    final platform = value['platform'] ?? 'android';
    final isTrace = platform == 'ios' && kind == 'identityTrace';
    if (value['scope'] != scope ||
        !const {'android', 'ios'}.contains(platform) ||
        id is! String ||
        !RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        ).hasMatch(id) ||
        time is! int ||
        time < 946684800000 ||
        time > 4102444800000 ||
        main is! bool ||
        (!isTrace &&
            !const {
              'argument',
              'state',
              'assertion',
              'other',
            }.contains(kind))) {
      throw const FormatException('Invalid crash summary');
    }
    event = DiagnosticEvent(
      operation: isTrace
          ? DiagnosticOperation.iosIdentityTrace
          : platform == 'ios'
          ? DiagnosticOperation.iosNativeCrash
          : main
          ? DiagnosticOperation.androidMainUnhandled
          : DiagnosticOperation.androidBackgroundUnhandled,
      result: isTrace ? DiagnosticResult.received : DiagnosticResult.failed,
      time: DateTime.fromMillisecondsSinceEpoch(time, isUtc: true),
      traceId: id,
      failureKind: isTrace
          ? null
          : DiagnosticFailureKind.values.byName(kind as String),
      iosTrace: isTrace
          ? DiagnosticIosTraceDetails.fromJson(
              value['iosTrace'] is Map ? value['iosTrace'] as Map : const {},
            )
          : null,
      iosCrash: platform == 'ios' && !isTrace
          ? DiagnosticIosCrashDetails.fromJson(
              value['iosCrash'] is Map ? value['iosCrash'] as Map : const {},
            )
          : null,
    );
  }

  late final DiagnosticEvent event;
  String get id => event.traceId;
}

abstract interface class NativeCrashPort {
  Future<void> bind(String? scope);
  Future<List<NativeCrashSummary>> read(String scope);
  Future<void> acknowledge(String scope, List<String> ids);
}

/// At-least-once transfer between two durable stores. IDs correlate duplicates
/// if the process dies after journal commit but before native acknowledgement.
class NativeCrashImporter {
  NativeCrashImporter(this.port);
  final NativeCrashPort port;
  final _tails = <String, Future<bool>>{};
  final _recorded = <DiagnosticJournal, Set<String>>{};
  bool _closed = false;

  Future<bool> activate(String scope, DiagnosticJournal journal) async {
    if (_closed) return false;
    try {
      // Send immediately, never delay binding behind a previous account's IO.
      await port.bind(scope);
      if (_closed) return false;
      return await importPending(scope, journal);
    } catch (_) {
      return false;
    }
  }

  /// Upload preparation reads its captured owner without rebinding a newer login.
  Future<bool> importPending(String scope, DiagnosticJournal journal) async {
    if (_closed) return false;
    try {
      final previous = _tails[scope];
      final result = _importAfter(previous, scope, journal);
      _tails[scope] = result;
      try {
        return await result;
      } finally {
        if (identical(_tails[scope], result)) _tails.remove(scope);
      }
    } catch (_) {
      return false; // Does not interfere with startup/login or error handlers.
    }
  }

  Future<bool> _importAfter(
    Future<bool>? previous,
    String scope,
    DiagnosticJournal journal,
  ) async {
    if (previous != null) await previous;
    if (_closed) return false;
    try {
      final records = await port.read(scope);
      if (_closed) return false;
      if (records.isEmpty) return true;
      final seen = _recorded.putIfAbsent(journal, () => <String>{});
      for (final record in records) {
        if (seen.add(record.id)) journal.record(record.event);
      }
      // Keep this exact journal even when a new account becomes active.
      await journal.flush(requireOpen: true);
      if (_closed) return false;
      await port.acknowledge(scope, records.map((r) => r.id).toList());
      for (final record in records) {
        seen.remove(record.id);
      }
      return true;
    } catch (_) {
      return false; // Native records remain for next activation/resume.
    }
  }

  void close() {
    _closed = true;
    _clearBinding();
  }

  Future<void> _clearBinding() async {
    try {
      await port.bind(null);
    } catch (_) {
      /* best effort */
    }
  }
}
