import 'dart:async';
import 'dart:convert';
import 'diagnostic_agent_details.dart';
import 'diagnostic_event.dart';
import 'diagnostic_archive.dart';

/// PHONEAGENT_DIAGNOSTIC_LOG_LEVEL is a build-time dart-define. INFO keeps
/// milestones and failures; DEBUG also keeps per-event and media frame detail.
enum DiagnosticLogLevel {
  debug,
  info,
  warn,
  error;

  static DiagnosticLogLevel parse(String value) =>
      switch (value.trim().toUpperCase()) {
        'DEBUG' => debug,
        'WARN' => warn,
        'ERROR' => error,
        _ => info,
      };
}

const _configuredLogLevel = String.fromEnvironment(
  'PHONEAGENT_DIAGNOSTIC_LOG_LEVEL',
  defaultValue: 'INFO',
);

DiagnosticLogLevel get configuredDiagnosticLogLevel =>
    DiagnosticLogLevel.parse(_configuredLogLevel);

abstract interface class DiagnosticStore {
  Future<String?> read();
  Future<void> write(String value);
}

class DiagnosticSnapshot {
  const DiagnosticSnapshot(this.watermark, this.events, {this.hasMore = false});
  final int watermark;
  final List<DiagnosticEvent> events;
  final bool hasMore;
}

/// Serialized, bounded account-scoped journal. Storage failures never overwrite
/// an unread journal; a successful upload only acknowledges its own watermark.
class DiagnosticJournal {
  DiagnosticJournal(
    this.store, {
    this.capacity = 256,
    this.flushDelay = const Duration(milliseconds: 500),
    DiagnosticLogLevel? minimumLevel,
  }) : minimumLevel =
           minimumLevel ?? configuredDiagnosticLogLevel,
       _archiveFactory = null;
  DiagnosticJournal.archived(
    Future<DiagnosticArchive> Function() archive, {
    required DiagnosticStore legacyStore,
    this.capacity = 256,
    this.flushDelay = const Duration(milliseconds: 500),
    DiagnosticLogLevel? minimumLevel,
  }) : store = legacyStore,
       minimumLevel =
           minimumLevel ?? configuredDiagnosticLogLevel,
       _archiveFactory = archive;
  final DiagnosticStore store;
  final Future<DiagnosticArchive> Function()? _archiveFactory;
  DiagnosticArchive? _archive;
  List<DiagnosticEvent>? _inFlight;
  bool _legacyCleaned = false;
  final int capacity;
  final Duration flushDelay;
  final DiagnosticLogLevel minimumLevel;
  final _pending = <DiagnosticEvent>[];
  List<(int, DiagnosticEvent)> _events = [];
  int _sequence = 0;
  bool _loaded = false, _closed = false;
  Future<void> _tail = Future.value();
  Timer? _timer;

  void record(DiagnosticEvent event) {
    if (_closed || !_allows(event)) return;
    _pending.add(event);
    if (_pending.length > capacity) _pending.removeAt(0);
    _timer ??= Timer(flushDelay, () {
      _timer = null;
      _flush().catchError((Object _) {});
    });
  }

  bool _allows(DiagnosticEvent event) {
    // Already retained native evidence must reach durable storage before ack,
    // even when ordinary live milestones are filtered by the build log level.
    if (event.operation == DiagnosticOperation.iosIdentityTrace &&
        event.iosTrace != null) {
      return true;
    }
    final level = event.result == DiagnosticResult.failed
        ? DiagnosticLogLevel.error
        : event.operation == DiagnosticOperation.agentEvent &&
              event.agent?.frame == DiagnosticAgentFrame.finalResponse
        ? DiagnosticLogLevel.info
        : event.operation == DiagnosticOperation.agentEvent ||
              (event.operation == DiagnosticOperation.voiceMedia &&
                  event.result == DiagnosticResult.received)
        ? DiagnosticLogLevel.debug
        : DiagnosticLogLevel.info;
    return level.index >= minimumLevel.index;
  }

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<void> _load() async {
    if (_loaded) return;
    final raw = await store.read();
    final loaded = <(int, DiagnosticEvent)>[];
    var sequenceCursor = 0;
    if (raw != null) {
      if (raw.length > 512 * 1024) throw const FormatException('Journal size');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['version'] != 1) throw const FormatException('Journal version');
      for (final row in json['events'] as List) {
        final value = row as Map<String, dynamic>;
        final sequence = value['sequence'] as int;
        if (sequence <= sequenceCursor) {
          throw const FormatException('Journal sequence');
        }
        sequenceCursor = sequence;
        loaded.add((sequence, DiagnosticEvent.fromJson(value)));
      }
    }
    _events = loaded.length > capacity
        ? loaded.sublist(loaded.length - capacity)
        : loaded;
    _sequence = sequenceCursor;
    _loaded = true;
  }

  String _encode(List<(int, DiagnosticEvent)> events) => jsonEncode({
    'version': 1,
    'events': [
      for (final row in events) {'sequence': row.$1, ...row.$2.toJson()},
    ],
  });

  Future<void> _drain() async {
    if (_archiveFactory != null) {
      await _drainArchive();
      return;
    }
    await _load();
    while (_pending.isNotEmpty) {
      _events.add((++_sequence, _pending.removeAt(0)));
    }
    if (_events.length > capacity) {
      _events = _events.sublist(_events.length - capacity);
    }
    await store.write(_encode(_events));
  }

  Future<void> _drainArchive() async {
    final archive = _archive ??= await _archiveFactory!();
    if (!_legacyCleaned) {
      if (!await archive.legacyImported) {
        await _load();
        await archive.append(
          _events.map((e) => e.$2).toList(),
          importLegacy: true,
        );
      }
      // Marker and imported events are committed together; if this clear fails,
      // retry only the clear, never import again or overwrite unread old data.
      await store.write(jsonEncode({'version': 1, 'events': <Object>[]}));
      _events = [];
      _legacyCleaned = true;
    }
    while (_inFlight != null || _pending.isNotEmpty) {
      if (_inFlight == null) {
        _inFlight = List<DiagnosticEvent>.of(_pending);
        _pending.clear();
      }
      await archive.append(_inFlight!);
      _inFlight = null;
    }
  }

  Future<void> _flush() => _serial(_drain);

  /// Best-effort callers must handle storage failure. This does not promise
  /// durability if the OS terminates the process before async storage completes.
  Future<void> flush({bool requireOpen = false}) {
    _timer?.cancel();
    _timer = null;
    return _serial(() async {
      if (requireOpen && _closed) throw StateError('Journal closed');
      if (!_closed) await _drain();
    });
  }

  Future<DiagnosticSnapshot> snapshot({int? maxBytes}) => _serial(() async {
    if (_closed) throw StateError('Journal closed');
    await _drain();
    if (_archive != null) {
      final value = await _archive!.snapshot(maxBytes: maxBytes);
      return DiagnosticSnapshot(
        value.watermark,
        value.events,
        hasMore: value.hasMore,
      );
    }
    return DiagnosticSnapshot(
      _sequence,
      List.unmodifiable(_events.map((e) => e.$2)),
    );
  });

  Future<void> acknowledge(int watermark) => _serial(() async {
    if (_closed) throw StateError('Journal closed');
    await _drain();
    if (_archive != null) {
      await _archive!.acknowledge(watermark);
      return;
    }
    final remaining = _events.where((e) => e.$1 > watermark).toList();
    await store.write(_encode(remaining));
    _events = remaining;
  });

  void close() {
    _closed = true;
    _timer?.cancel();
    _timer = null;
    _flush().catchError((Object _) {});
  }
}
