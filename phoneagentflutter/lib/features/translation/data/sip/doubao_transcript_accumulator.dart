import '../../domain/sip/domestic_translation_model.dart';
import '../../domain/translation_call_view.dart';
import '../../domain/sip/sip_lease.dart';

/// Shared native comma continuation and overlapping AST text policy, no logs.
class DoubaoTranscriptAccumulator {
  DoubaoTranscriptAccumulator({
    required this.leg,
    required this.sourceLanguage,
    required this.targetLanguage,
    DateTime Function()? now,
    String Function()? token,
  }) : _now = now ?? DateTime.now,
       _token = token ?? newDomesticModelToken;
  final String leg, sourceLanguage, targetLanguage;
  final DateTime Function() _now;
  final String Function() _token;
  String _id = '', _source = '', _translated = '';
  bool _closed = true, _sourceDone = false, _translationDone = false;
  bool _sourceJoin = false, _translationJoin = false, _pendingSourceEnd = false;
  DateTime? _commaEndedAt;

  TranslationTranscript? source(String text, int event) =>
      _apply(text, event, true);
  TranslationTranscript? translation(String text, int event) =>
      _apply(text, event, false);
  TranslationTranscript? _apply(String text, int event, bool source) {
    final clean = text.trim();
    if (clean.isEmpty && (_id.isEmpty || _closed)) return null;
    if (clean.length > 32000) {
      throw const SipLeaseFailure('MODEL_TEXT_OVERFLOW');
    }
    if (source &&
        event == 650 &&
        !_closed &&
        _pendingSourceEnd &&
        _translationDone) {
      _sourceDone = true;
      _pendingSourceEnd = false;
      _close();
    }
    if (clean.isNotEmpty) _ensure(source && event == 650, source);
    if (source) {
      final joining = _sourceJoin;
      _source = _sourceJoin
          ? _join(_source, clean)
          : event == 652
          ? _final(_source, clean)
          : _append(_source, clean);
      _sourceJoin = false;
      if (event == 650 && joining) _pendingSourceEnd = true;
      if (event == 652) {
        _sourceDone = true;
        _pendingSourceEnd = false;
      }
    } else {
      _translated = _translationJoin
          ? _join(_translated, clean)
          : event == 655
          ? _final(_translated, clean)
          : _append(_translated, clean);
      _translationJoin = false;
      if (event == 655) _translationDone = true;
    }
    if (_source.length > 64000 || _translated.length > 64000) {
      throw const SipLeaseFailure('MODEL_TEXT_OVERFLOW');
    }
    final complete = _sourceDone && _translationDone;
    if (complete) _close();
    return TranslationTranscript(
      id: _id,
      leg: leg,
      source: _source,
      translated: _translated,
      sourceLanguage: sourceLanguage,
      translatedLanguage: targetLanguage,
      isFinal:
          complete ||
          (_translationDone && _pendingSourceEnd && _source.isNotEmpty),
    );
  }

  void _ensure(bool forceNew, bool allowComma) {
    if (_id.isNotEmpty && !_closed && (!forceNew || _source.isEmpty)) return;
    final comma = _commaEndedAt;
    final gap = comma == null ? null : _now().difference(comma).inMilliseconds;
    if (allowComma &&
        _closed &&
        _id.isNotEmpty &&
        gap != null &&
        gap >= 0 &&
        gap <= 5000) {
      _closed = false;
      _sourceDone = false;
      _translationDone = false;
      _commaEndedAt = null;
      _sourceJoin = true;
      _translationJoin = true;
      return;
    }
    _id = 'turn-${_token()}';
    _source = '';
    _translated = '';
    _closed = false;
    _sourceDone = false;
    _translationDone = false;
    _sourceJoin = false;
    _translationJoin = false;
    _pendingSourceEnd = false;
    _commaEndedAt = null;
  }

  void _close() {
    _closed = true;
    _commaEndedAt = _comma(_source) || _comma(_translated) ? _now() : null;
  }

  static bool _comma(String value) =>
      value.endsWith(',') || value.endsWith('，');
  static String _join(String current, String next) => current.isEmpty
      ? next
      : '$current${current.endsWith(',') && next.isNotEmpty ? ' ' : ''}$next';
  static String _final(String current, String next) =>
      next.length >= current.length || current.isEmpty
      ? next
      : _append(current, next);
  static String _append(String current, String delta) {
    if (current.isEmpty) return delta;
    if (delta.isEmpty ||
        current == delta ||
        current.endsWith(delta) ||
        current.contains(delta)) {
      return current;
    }
    if (delta.startsWith(current)) return delta;
    for (
      var overlap = current.length < delta.length
          ? current.length
          : delta.length;
      overlap > 0;
      overlap--
    ) {
      if (current.endsWith(delta.substring(0, overlap))) {
        return current + delta.substring(overlap);
      }
    }
    return current + delta;
  }
}
