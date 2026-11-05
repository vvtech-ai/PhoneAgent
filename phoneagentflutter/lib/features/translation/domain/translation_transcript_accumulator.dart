import 'translation_call_view.dart';
import 'translation_realtime_event.dart';

/// Independent source/translation deltas; final does not discard later output.
class TranslationTranscriptAccumulator {
  TranslationTranscriptAccumulator(this.userLanguage, this.merchantLanguage);
  final String userLanguage, merchantLanguage;
  final Map<String, TranslationTranscript> _segments = {};
  List<TranslationTranscript> get items => List.unmodifiable(_segments.values);

  void apply(TranslationRealtimeEvent event, {bool Function(String)? accepts}) {
    if (event is TranslationTranscriptDelta) {
      final leg = event.sourceLeg.trim().toLowerCase();
      final key = '$leg:${event.segmentId}';
      if (accepts != null && !accepts(key)) return;
      final previous = _segments[key];
      final input = event.kind == 'input';
      final source = previous?.source ?? '';
      final translated = previous?.translated ?? '';
      final next = event.replace
          ? event.text
          : (input ? source : translated) + event.text;
      _segments[key] = TranslationTranscript(
        id: event.segmentId,
        leg: leg,
        source: input ? next : source,
        translated: input ? translated : next,
        sourceLanguage: leg == 'user' ? userLanguage : merchantLanguage,
        translatedLanguage: leg == 'user' ? merchantLanguage : userLanguage,
        isFinal: (previous?.isFinal ?? false) || event.isFinal,
      );
    } else if (event is TranslationConnectPrompt) {
      if (accepts != null && !accepts('system:${event.segmentId}')) return;
      _segments['system:${event.segmentId}'] = TranslationTranscript(
        id: event.segmentId,
        leg: 'system',
        source: event.source,
        translated: event.translated,
        sourceLanguage: userLanguage,
        translatedLanguage: merchantLanguage,
        isFinal: true,
      );
    }
  }
}
