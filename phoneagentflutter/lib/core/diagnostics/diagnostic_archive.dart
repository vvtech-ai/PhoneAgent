import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'diagnostic_archive_files.dart';
import 'diagnostic_event.dart';

class DiagnosticArchiveSnapshot {
  const DiagnosticArchiveSnapshot(
    this.watermark,
    this.events, {
    this.hasMore = false,
  });
  final int watermark;
  final List<DiagnosticEvent> events;
  final bool hasMore;
}

/// Shared retention and commit rules, independent of Flutter and native APIs.
/// A committed index is the only source of truth; unreferenced files are garbage.
class DiagnosticArchive {
  DiagnosticArchive(
    this.files, {
    DateTime Function()? clock,
    this.maxFileBytes = 5 * 1024 * 1024,
  }) : clock = clock ?? DateTime.now {
    if (maxFileBytes <= 0 || maxFileBytes > 5 * 1024 * 1024) {
      throw ArgumentError.value(maxFileBytes);
    }
  }

  final DiagnosticArchiveFiles files;
  final DateTime Function() clock;
  final int maxFileBytes;
  static const retainDays = 15;
  static const _indexName = 'index.json';
  static final _fileName = RegExp(r'^log-\d{4}-\d{2}-\d{2}-[1-9]\d*\.jsonl$');

  Future<bool> get legacyImported =>
      files.transaction(() async => (await _load()).legacyImported);

  Future<void> append(
    List<DiagnosticEvent> events, {
    bool importLegacy = false,
  }) {
    // Copy before queuing: the caller can reuse/clear its pending list.
    final batch = List<DiagnosticEvent>.of(events);
    return files.transaction(() async {
      if (batch.isEmpty && !importLegacy) return;
      final index = await _load();
      if (importLegacy && index.legacyImported) return;
      if (batch.isEmpty) {
        await _save(
          _Index(
            index.sequence,
            index.acknowledged,
            index.chunks,
            legacyImported: true,
          ),
        );
        return;
      }
      final now = clock();
      final day = _day(now);
      final retained = _retained(index, now);
      await _collect(index);
      var sequence = index.sequence;
      final lines = <String>[];
      for (final event in batch) {
        if (sequence >= 9007199254740991) {
          throw StateError('Diagnostic sequence exhausted');
        }
        lines.add(jsonEncode({'sequence': ++sequence, ...event.toJson()}));
      }
      var content = '${lines.join('\n')}\n';
      if (utf8.encode(content).length > maxFileBytes) {
        throw StateError('Diagnostic batch exceeds file limit');
      }
      var first = index.sequence + 1;
      if (retained.isNotEmpty) {
        final last = retained.last;
        if (last.day == day &&
            last.bytes + utf8.encode(content).length <= maxFileBytes) {
          final previous = await _readChunk(last);
          content = previous + content;
          first = last.first;
          retained.removeLast();
        }
      }
      final bytes = utf8.encode(content);
      final chunk = _Chunk(
        'log-$day-$sequence.jsonl',
        day,
        first,
        sequence,
        bytes.length,
        sha256.convert(bytes).toString(),
      );
      await files.replace(chunk.name, content);
      await _save(
        _Index(
          sequence,
          index.acknowledged,
          [...retained, chunk],
          legacyImported: index.legacyImported || importLegacy,
        ),
      );
      // No fallible operation after commit. GC is retried by the next operation,
      // so a failed deletion cannot make the caller replay an accepted batch.
    });
  }

  Future<DiagnosticArchiveSnapshot> snapshot({
    int? maxBytes,
  }) => files.transaction(() async {
    if (maxBytes != null && maxBytes <= 0) throw ArgumentError.value(maxBytes);
    final index = await _prune(await _load());
    final result = <DiagnosticEvent>[];
    var bytes = 0;
    var watermark = index.acknowledged;
    for (final chunk in index.chunks) {
      final raw = await _readChunk(chunk);
      for (final line in const LineSplitter().convert(raw)) {
        final row = jsonDecode(line) as Map<String, dynamic>;
        if ((row['sequence'] as int) > index.acknowledged) {
          final event = DiagnosticEvent.fromJson(row);
          final size = utf8.encode(jsonEncode(event.toJson())).length + 1;
          if (maxBytes != null && bytes + size > maxBytes) {
            if (result.isEmpty) {
              throw StateError('Diagnostic event exceeds budget');
            }
            await _collect(index);
            return DiagnosticArchiveSnapshot(
              watermark,
              List.unmodifiable(result),
              hasMore: true,
            );
          }
          result.add(event);
          bytes += size;
          watermark = row['sequence'] as int;
        }
      }
    }
    await _collect(index);
    return DiagnosticArchiveSnapshot(index.sequence, List.unmodifiable(result));
  });

  Future<void> acknowledge(int watermark) => files.transaction(() async {
    final index = await _load();
    if (watermark < 0 || watermark > index.sequence) {
      throw ArgumentError.value(watermark, 'watermark');
    }
    final acknowledged = watermark > index.acknowledged
        ? watermark
        : index.acknowledged;
    final next = _Index(
      index.sequence,
      acknowledged,
      index.chunks,
      legacyImported: index.legacyImported,
    );
    // Persist the tombstone before deleting any file, including an empty index.
    final committed = await _prune(next, force: true);
    await _collect(committed);
  });

  List<_Chunk> _retained(_Index index, DateTime now) {
    // UTC is used only for calendar arithmetic; this is the device's local date.
    final cutoff = DateTime.utc(now.year, now.month, now.day - retainDays + 1);
    return index.chunks
        .where(
          (chunk) =>
              !_parseDay(chunk.day).isBefore(cutoff) &&
              chunk.last > index.acknowledged,
        )
        .toList();
  }

  Future<_Index> _prune(_Index index, {bool force = false}) async {
    final retained = _retained(index, clock());
    final next = _Index(
      index.sequence,
      index.acknowledged,
      retained,
      legacyImported: index.legacyImported,
    );
    if (force || retained.length != index.chunks.length) await _save(next);
    return next;
  }

  Future<void> _collect(_Index index) async {
    final keep = index.chunks.map((e) => e.name).toSet();
    for (final name in await files.names()) {
      if (_fileName.hasMatch(name) && !keep.contains(name)) {
        await files.remove(name);
      }
    }
  }

  Future<_Index> _load() async {
    final raw = await files.read(_indexName);
    if (raw == null) {
      if ((await files.names()).any(_fileName.hasMatch)) {
        throw const FormatException('Archive index missing');
      }
      const empty = _Index(0, 0, []);
      // Establish the cursor before the very first chunk is written. This
      // distinguishes an interrupted first append from a lost existing index.
      await _save(empty);
      return empty;
    }
    final json = jsonDecode(raw) as Map<String, dynamic>;
    if (json['version'] != 1) throw const FormatException('Archive version');
    final sequence = json['sequence'] as int;
    final acknowledged = json['acknowledged'] as int;
    if (sequence < 0 ||
        sequence > 9007199254740991 ||
        acknowledged < 0 ||
        acknowledged > sequence) {
      throw const FormatException('Archive cursor');
    }
    final chunks = <_Chunk>[];
    var previous = 0;
    for (final item in json['files'] as List) {
      final row = item as Map<String, dynamic>;
      final chunk = _Chunk(
        row['name'] as String,
        row['day'] as String,
        row['first'] as int,
        row['last'] as int,
        row['bytes'] as int,
        row['sha256'] as String,
      );
      _parseDay(chunk.day);
      if (!_fileName.hasMatch(chunk.name) ||
          chunk.name != 'log-${chunk.day}-${chunk.last}.jsonl' ||
          chunk.first <= previous ||
          chunk.last < chunk.first ||
          chunk.last > sequence ||
          chunk.bytes <= 0 ||
          chunk.bytes > maxFileBytes ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(chunk.digest)) {
        throw const FormatException('Archive file metadata');
      }
      previous = chunk.last;
      chunks.add(chunk);
    }
    final imported = json['legacyImported'];
    if (imported != null && imported is! bool) {
      throw const FormatException('Archive legacy marker');
    }
    return _Index(
      sequence,
      acknowledged,
      chunks,
      legacyImported: imported == true,
    );
  }

  Future<String> _readChunk(_Chunk chunk) async {
    final raw = await files.read(chunk.name);
    if (raw == null) throw const FormatException('Archive file missing');
    final bytes = utf8.encode(raw);
    if (bytes.length != chunk.bytes ||
        sha256.convert(bytes).toString() != chunk.digest ||
        !raw.endsWith('\n')) {
      throw const FormatException('Archive file integrity');
    }
    var sequence = chunk.first - 1;
    for (final line in const LineSplitter().convert(raw)) {
      final row = jsonDecode(line) as Map<String, dynamic>;
      if (row['sequence'] != ++sequence) {
        throw const FormatException('Archive row sequence');
      }
      DiagnosticEvent.fromJson(row);
    }
    if (sequence != chunk.last) {
      throw const FormatException('Archive row count');
    }
    return raw;
  }

  Future<void> _save(_Index index) => files.replace(
    _indexName,
    jsonEncode({
      'version': 1,
      'sequence': index.sequence,
      'acknowledged': index.acknowledged,
      'legacyImported': index.legacyImported,
      'files': [for (final chunk in index.chunks) chunk.toJson()],
    }),
  );

  static String _day(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
  static DateTime _parseDay(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      throw const FormatException('Archive date');
    }
    final parsed = DateTime.parse('${value}T00:00:00Z');
    if (_day(parsed) != value) throw const FormatException('Archive date');
    return parsed;
  }
}

class _Index {
  const _Index(
    this.sequence,
    this.acknowledged,
    this.chunks, {
    this.legacyImported = false,
  });
  final int sequence, acknowledged;
  final List<_Chunk> chunks;
  final bool legacyImported;
}

class _Chunk {
  const _Chunk(
    this.name,
    this.day,
    this.first,
    this.last,
    this.bytes,
    this.digest,
  );
  final String name, day, digest;
  final int first, last, bytes;
  Map<String, Object> toJson() => {
    'name': name,
    'day': day,
    'first': first,
    'last': last,
    'bytes': bytes,
    'sha256': digest,
  };
}
