import 'translation_call_environment.dart';

enum TranslationPhase {
  preflight,
  dialing,
  ringing,
  connected,
  translating,
  ended,
  failed,
}

class TranslationTranscript {
  const TranslationTranscript({
    required this.id,
    required this.leg,
    required this.source,
    required this.translated,
    this.sourceLanguage = '',
    this.translatedLanguage = '',
    this.isFinal = false,
  });
  final String id, leg, source, translated, sourceLanguage, translatedLanguage;
  final bool isFinal;
  String get key => '$leg:$id';
  bool get mine => const ['user', 'local'].contains(leg.toLowerCase());
  String get primary => (mine ? source : translated).trim().isNotEmpty
      ? (mine ? source : translated).trim()
      : (mine ? translated : source).trim();
  String? get secondary {
    final preferred = (mine ? source : translated).trim();
    final alternate = (mine ? translated : source).trim();
    String family(String value) =>
        value.trim().replaceAll('_', '-').split('-').first.toLowerCase();
    if (preferred.isEmpty ||
        alternate.isEmpty ||
        preferred == alternate ||
        (family(sourceLanguage).isNotEmpty &&
            family(sourceLanguage) == family(translatedLanguage))) {
      return null;
    }
    return alternate;
  }
}

class TranslationCallView {
  const TranslationCallView({
    this.phase = TranslationPhase.preflight,
    this.elapsedSeconds = 0,
    this.muted = false,
    this.speaker = false,
    this.dialPad = false,
    this.dtmfFeedbackAvailable = false,
    this.enhancedDtmfFeedback = true,
    this.transcripts = const [],
    this.error = '',
    this.dtmf = '',
    this.environment = const TranslationCallEnvironment(),
    this.controlsBusy = false,
    this.stopping = false,
    this.settlementNotice = '',
  });
  final TranslationPhase phase;
  final TranslationCallEnvironment environment;
  final int elapsedSeconds;
  final bool muted, speaker, dialPad, dtmfFeedbackAvailable;
  final bool enhancedDtmfFeedback;
  final bool controlsBusy, stopping;
  final List<TranslationTranscript> transcripts;
  final String error, dtmf;
  final String settlementNotice;
  bool get terminal =>
      phase == TranslationPhase.ended || phase == TranslationPhase.failed;
  String get phaseText => switch (phase) {
    TranslationPhase.preflight => '正在检测通话环境',
    TranslationPhase.dialing => '正在拨号',
    TranslationPhase.ringing => '正在振铃',
    TranslationPhase.connected => '翻译准备中',
    TranslationPhase.translating => '实时翻译 · 已接通',
    TranslationPhase.ended => '通话已结束',
    TranslationPhase.failed => '通话不可用',
  };
  TranslationCallView copy({
    TranslationPhase? phase,
    TranslationCallEnvironment? environment,
    int? elapsedSeconds,
    bool? muted,
    bool? speaker,
    bool? dialPad,
    bool? dtmfFeedbackAvailable,
    bool? enhancedDtmfFeedback,
    List<TranslationTranscript>? transcripts,
    String? error,
    String? dtmf,
    bool? controlsBusy,
    bool? stopping,
    String? settlementNotice,
  }) => TranslationCallView(
    phase: phase ?? this.phase,
    environment: environment ?? this.environment,
    elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
    muted: muted ?? this.muted,
    speaker: speaker ?? this.speaker,
    dialPad: dialPad ?? this.dialPad,
    dtmfFeedbackAvailable: dtmfFeedbackAvailable ?? this.dtmfFeedbackAvailable,
    enhancedDtmfFeedback: enhancedDtmfFeedback ?? this.enhancedDtmfFeedback,
    transcripts: transcripts ?? this.transcripts,
    error: error ?? this.error,
    dtmf: dtmf ?? this.dtmf,
    controlsBusy: controlsBusy ?? this.controlsBusy,
    stopping: stopping ?? this.stopping,
    settlementNotice: settlementNotice ?? this.settlementNotice,
  );
}
