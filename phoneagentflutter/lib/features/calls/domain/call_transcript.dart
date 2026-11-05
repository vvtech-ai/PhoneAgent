enum CallSpeaker { assistant, remote }

class CallTranscriptLine {
  const CallTranscriptLine(
    this.speaker,
    this.text, {
    this.attemptId = '',
    this.segmentIndex,
    this.snapshotIndex,
  });
  final CallSpeaker speaker;
  final String text, attemptId;
  final int? segmentIndex;

  /// Snapshot physical line number; matches SSE when both use one display format.
  final int? snapshotIndex;
}

/// Matches the live call-session snapshot format, not the more permissive
/// historical receipt format. Duplicate utterances are meaningful.
class CallTranscript {
  CallTranscript({List<CallTranscriptLine> lines = const [], this.source = ''})
    : lines = List.unmodifiable(lines);
  final List<CallTranscriptLine> lines;
  final String source;

  static bool _same(CallTranscriptLine a, CallTranscriptLine b) =>
      a.speaker == b.speaker && a.text.trim() == b.text.trim();

  CallTranscript live(String attemptId, int segmentIndex, String text) {
    final parsed = parse(text);
    if (parsed.length != 1 ||
        attemptId.isEmpty ||
        segmentIndex < 1 ||
        lines.any(
          (l) => l.attemptId == attemptId && l.segmentIndex == segmentIndex,
        )) {
      return this;
    }
    final line = CallTranscriptLine(
      parsed.single.speaker,
      parsed.single.text,
      attemptId: attemptId,
      segmentIndex: segmentIndex,
    );
    final next = lines.toList();
    final snapshotRows = _indexedLines(source);
    final inSnapshot = snapshotRows.any(
      (entry) => entry.$1 == segmentIndex && _same(entry.$2, line),
    );
    final unbound = inSnapshot
        ? next.indexWhere(
            (l) =>
                l.segmentIndex == null &&
                l.snapshotIndex == segmentIndex &&
                _same(l, line),
          )
        : -1;
    if (unbound >= 0) next.removeAt(unbound);
    final later = next.indexWhere(
      (l) =>
          (l.attemptId == attemptId &&
              l.segmentIndex != null &&
              l.segmentIndex! > segmentIndex) ||
          (l.segmentIndex == null &&
              l.snapshotIndex != null &&
              l.snapshotIndex! > segmentIndex &&
              snapshotRows.any(
                (entry) => entry.$1 == l.snapshotIndex && _same(entry.$2, l),
              )),
    );
    if (later >= 0) {
      next.insert(later, line);
    } else if (unbound >= 0) {
      next.insert(unbound.clamp(0, next.length), line);
    } else {
      next.add(line);
    }
    return CallTranscript(lines: next, source: source);
  }

  CallTranscript merge(String incoming) {
    final normalized = incoming.trim();
    if (normalized == source) return this;
    final parsed = _indexedLines(normalized);
    final next = lines.toList();
    final used = <CallTranscriptLine>{};
    for (final entry in parsed.indexed) {
      final segmentIndex = entry.$2.$1;
      final line = entry.$2.$2;
      final match = next
          .where(
            (candidate) =>
                !used.contains(candidate) &&
                _same(candidate, line) &&
                (candidate.segmentIndex == segmentIndex ||
                    candidate.snapshotIndex == segmentIndex),
          )
          .firstOrNull;
      if (match != null) {
        used.add(match);
        continue;
      }
      CallTranscriptLine? anchor;
      for (final future in parsed.skip(entry.$1 + 1)) {
        anchor = next
            .where(
              (candidate) =>
                  !used.contains(candidate) &&
                  _same(candidate, future.$2) &&
                  (candidate.segmentIndex == future.$1 ||
                      candidate.snapshotIndex == future.$1),
            )
            .firstOrNull;
        if (anchor != null) break;
      }
      // A polling prefix can arrive after a later numbered SSE segment.
      anchor ??= next
          .where(
            (candidate) =>
                candidate.segmentIndex != null &&
                candidate.segmentIndex! > segmentIndex,
          )
          .firstOrNull;
      final snapshotLine = CallTranscriptLine(
        line.speaker,
        line.text,
        snapshotIndex: segmentIndex,
      );
      next.insert(
        anchor == null ? next.length : next.indexOf(anchor),
        snapshotLine,
      );
      used.add(snapshotLine);
    }
    return CallTranscript(lines: next, source: normalized);
  }

  static List<CallTranscriptLine> parse(String detail) => [
    for (final entry in _indexedLines(detail)) entry.$2,
  ];

  // SSE numbers display lines, including unprefixed continuations that the
  // snapshot parser does not display until their own final caption arrives.
  static List<(int, CallTranscriptLine)> _indexedLines(String detail) => [
    for (final entry in detail.split('\n').indexed)
      if (_line(entry.$2.trim()) case final line?) (entry.$1 + 1, line),
  ];

  static CallTranscriptLine? _line(String line) {
    final match = RegExp(
      r'^(assistant|callee|merchant|remote|AI|助手|对方|商家|被叫)[:：]\s*(.*)$',
      caseSensitive: false,
    ).firstMatch(line);
    if (match == null || match.group(2)!.trim().isEmpty) return null;
    return CallTranscriptLine(
      const {'assistant', 'ai', '助手'}.contains(match.group(1)!.toLowerCase())
          ? CallSpeaker.assistant
          : CallSpeaker.remote,
      match.group(2)!.trim(),
    );
  }
}
