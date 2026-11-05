/// Fixed v65 AgentTtsBridge / MarkdownText policy, without platform dependencies.
class SpeechTextPolicy {
  // v66 task voice default; current runtime resolves the task TTS selection.
  static const speaker = 'Maia';
  static String cleanStreamingSegment(String text) {
    return clean(text)
        .replaceAll(RegExp(r'(?<!\w)\*{1,3}(?=[^\s\d])'), '')
        .replaceAll(RegExp(r'(?<=\S)\*{1,3}(?!\w)'), '')
        .replaceAll(RegExp(r'(?<!\w)~{2}(?=[^\s\d])'), '')
        .replaceAll(RegExp(r'(?<=\S)~{2}(?!\w)'), '')
        .replaceAll(RegExp(r'^\*{1,3}$|^~{2}$'), '');
  }

  static int sentenceEnd(String text) {
    final full = text.indexOf(RegExp(r'[。！？\n.!?]'));
    if (full >= 0) return full;
    return text.length > 80 ? text.indexOf(RegExp(r'[，、；,;]')) : -1;
  }

  static String clean(String text) {
    var result = text;
    for (final (pattern, group) in _patterns) {
      result = result.replaceAllMapped(
        RegExp(pattern, multiLine: true),
        (match) => group == 0 ? '' : match.group(group)!,
      );
    }
    return result.replaceAll(RegExp(r'[ \t]+'), ' ').trim();
  }

  static const _patterns = <(String, int)>[
    (r'```[\s\S]*?```', 0),
    (r'`([^`]+)`', 1),
    (r'!\[[^\]]*]\([^)]*\)', 0),
    (r'\[([^\]]+)]\([^)]*\)', 1),
    (r'(\*\*\*|___)([^*_\n]+?)\1', 2),
    (r'(\*\*|__)([^*_\n]+?)\1', 2),
    (r'(?<![\w*])\*([^*\n]+?)\*(?![\w*])', 1),
    (r'(?<![\w_])_([^_\n]+?)_(?![\w_])', 1),
    (r'~~([^~\n]+?)~~', 1),
    (r'^\s{0,3}#{1,6}\s+', 0),
    (r'^\s{0,3}>\s+', 0),
    (r'^\s{0,3}[-*+]\s+', 0),
    (r'^\s{0,3}\d+\.\s+', 0),
    (r'^\s*[-*_]{3,}\s*$', 0),
  ];
}

/// Keeps incomplete Markdown out of speech while reply text arrives in parts.
/// The existing cleaner still handles decoration on each completed speech part.
class SpeechMarkdownStream {
  int _fenceLength = 0;
  bool _fenceMultiline = false;
  bool _fenceCloseCandidate = false;
  int _fenceLineIndent = 0;
  bool _ticksAtLineStart = false;
  int _labelDepth = 0;
  bool _imageLabel = false;
  bool _imageCandidate = false;
  bool _imageAfterBang = false;
  StringBuffer _candidateLabel = StringBuffer();
  bool _afterLabel = false;
  int _destinationDepth = 0;
  int _nestedDestinationDepth = 0;
  bool _nestedAfterLabel = false;
  bool _pendingBang = false;
  bool _escaped = false;
  int _ticks = 0;

  int get bufferedLength => _candidateLabel.length;

  String append(String text) {
    final spoken = StringBuffer();
    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      if (_fenceCloseCandidate) {
        if (char == ' ' || char == '\t') continue;
        _fenceCloseCandidate = false;
        if (char == '\n' || char == '\r') {
          _fenceLength = 0;
        } else {
          _fenceLineIndent = 4;
          continue;
        }
      }
      if (_fenceLength > 0) {
        if (char == '`') {
          if (_ticks == 0) _ticksAtLineStart = _fenceLineIndent <= 3;
          _ticks++;
          continue;
        }
        if (_ticks >= _fenceLength) {
          if (!_fenceMultiline ||
              _ticksAtLineStart && (char == '\n' || char == '\r')) {
            _fenceLength = 0;
          } else if (_ticksAtLineStart && (char == ' ' || char == '\t')) {
            _fenceCloseCandidate = true;
            _ticks = 0;
            continue;
          }
        }
        _ticks = 0;
        if (char == '\n') {
          _fenceMultiline = true;
          _fenceLineIndent = 0;
        } else if (char == ' ' && _fenceLineIndent < 4) {
          _fenceLineIndent++;
        } else {
          _fenceLineIndent = 4;
        }
        if (_fenceLength > 0) continue;
      }
      if (_destinationDepth > 0) {
        if (_escaped) {
          _escaped = false;
        } else if (char == r'\') {
          _escaped = true;
        } else if (char == '(') {
          _destinationDepth++;
        } else if (char == ')') {
          _destinationDepth--;
        }
        continue;
      }
      if (_labelDepth > 0) {
        if (_nestedDestinationDepth > 0) {
          if (_escaped) {
            _escaped = false;
          } else if (char == r'\') {
            _escaped = true;
          } else if (char == '(') {
            _nestedDestinationDepth++;
          } else if (char == ')') {
            _nestedDestinationDepth--;
          }
          continue;
        }
        if (_nestedAfterLabel) {
          _nestedAfterLabel = false;
          if (char == '(') {
            _nestedDestinationDepth = 1;
            continue;
          }
        }
        if (_escaped) {
          _writeLabel(spoken, char);
          _escaped = false;
        } else if (char == r'\') {
          _escaped = true;
        } else if (char == '[') {
          _labelDepth++;
        } else if (char == ']') {
          if (--_labelDepth == 0) {
            _afterLabel = true;
          } else {
            _nestedAfterLabel = true;
          }
        } else {
          _writeLabel(spoken, char);
        }
        continue;
      }
      if (_afterLabel) {
        _afterLabel = false;
        if (_imageCandidate) {
          if (char == '(') {
            _imageCandidate = false;
            _candidateLabel = StringBuffer();
            _destinationDepth = 1;
            continue;
          }
          spoken.write(_candidateLabel);
          _imageCandidate = false;
          _candidateLabel = StringBuffer();
        }
        if (char == '(') {
          _destinationDepth = 1;
          continue;
        }
      }
      if (_imageAfterBang) {
        _imageAfterBang = false;
        if (char == '[') {
          _labelDepth = 1;
          _imageLabel = false;
          _imageCandidate = true;
          continue;
        }
      }
      if (_pendingBang) {
        _pendingBang = false;
        if (char == '[') {
          _labelDepth = 1;
          _imageLabel = true;
          continue;
        }
        spoken.write('!');
      }
      if (char == '`') {
        _ticks++;
        continue;
      }
      if (_ticks >= 3) {
        _fenceLength = _ticks;
        _fenceMultiline = char == '\n';
        _fenceLineIndent = _fenceMultiline ? 0 : 4;
        _ticks = 0;
        continue;
      }
      if (_ticks > 0) {
        // Inline-code markers are decoration; their text remains speakable.
        _ticks = 0;
      }
      if (char == '!') {
        _pendingBang = true;
      } else if (char == '[') {
        _labelDepth = 1;
        _imageLabel = false;
      } else {
        spoken.write(char);
      }
    }
    if (_pendingBang) {
      spoken.write('!');
      _pendingBang = false;
      _imageAfterBang = true;
    }
    return spoken.toString();
  }

  void _writeLabel(StringBuffer spoken, String char) {
    if (_imageLabel) return;
    if (_imageCandidate) {
      _candidateLabel.write(char);
    } else {
      spoken.write(char);
    }
  }

  String finish() {
    final trailing = _imageCandidate ? _candidateLabel.toString() : '';
    reset();
    return trailing;
  }

  void reset() {
    _fenceLength = 0;
    _fenceMultiline = false;
    _fenceCloseCandidate = false;
    _fenceLineIndent = 0;
    _ticksAtLineStart = false;
    _labelDepth = 0;
    _imageLabel = false;
    _imageCandidate = false;
    _imageAfterBang = false;
    _candidateLabel = StringBuffer();
    _afterLabel = false;
    _destinationDepth = 0;
    _nestedDestinationDepth = 0;
    _nestedAfterLabel = false;
    _pendingBang = false;
    _escaped = false;
    _ticks = 0;
  }
}
