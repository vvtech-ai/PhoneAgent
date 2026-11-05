/// Fixed reasons for a visible committed call result's TTS handoff.
enum DiagnosticTtsNarrationDecision {
  turnInterrupted,
  preferenceNotReady,
  voiceDisabled,
  pageClosed,
  accountChanged,
  callActive,
  gateClosed,
  resultNotMatched,
  previousSpeechActive,
  enqueueRejected,
  queued,
}

class DiagnosticTtsNarrationDetails {
  const DiagnosticTtsNarrationDetails({
    required this.sequence,
    required this.decision,
  });

  final int sequence;
  final DiagnosticTtsNarrationDecision decision;

  Map<String, Object> toJson() => {
    'sequence': sequence.clamp(0, 9007199254740991),
    'decision': decision.name,
  };

  factory DiagnosticTtsNarrationDetails.fromJson(Map<String, dynamic> json) =>
      DiagnosticTtsNarrationDetails(
        sequence: json['sequence'] is int ? json['sequence'] as int : 0,
        decision: DiagnosticTtsNarrationDecision.values.firstWhere(
          (value) => value.name == json['decision'],
          orElse: () => DiagnosticTtsNarrationDecision.gateClosed,
        ),
      );
}
