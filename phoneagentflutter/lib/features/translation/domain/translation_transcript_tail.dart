import 'translation_call_view.dart';

/// Session-owned subtitle drain; never owns or prolongs audio resources.
class TranslationTranscriptTail {
  TranslationTranscriptTail(this.now);
  final DateTime Function() now;
  Set<String>? _keys;
  DateTime? _expires;
  bool get frozen => _keys != null;
  void freeze(Iterable<TranslationTranscript> items, {bool terminal = false}) {
    _keys ??= items.map((item) => item.key).toSet();
    if (terminal) _expires ??= now().add(const Duration(milliseconds: 500));
  }

  bool accepts(String key) =>
      _keys == null ||
      (_keys!.contains(key) && (_expires == null || !now().isAfter(_expires!)));
  List<TranslationTranscript> snapshot(Iterable<TranslationTranscript> items) =>
      [
        for (final item in items)
          TranslationTranscript(
            id: item.id,
            leg: item.leg,
            source: item.source,
            translated: item.translated,
            sourceLanguage: item.sourceLanguage,
            translatedLanguage: item.translatedLanguage,
            isFinal:
                item.isFinal ||
                (frozen &&
                    (item.source.trim().isNotEmpty ||
                        item.translated.trim().isNotEmpty)),
          ),
      ];
}
