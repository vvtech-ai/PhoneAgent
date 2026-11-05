enum DiagnosticAudioOwner {
  conversationCapture,
  conversationTts,
  callMonitor,
  identityCapture,
  clonePreview,
  recording,
  translationAppAudio,
  translationSip,
  translationLivekit,
  unknown,
}

enum DiagnosticAudioStage { acquire, release, stop, stopWait, unknown }

/// Process-local numbers are correlation hints, not backend session identities.
class DiagnosticAudioDetails {
  const DiagnosticAudioDetails({
    required this.owner,
    required this.stage,
    required this.request,
    this.lease = 0,
    this.blockedBy,
  });
  final DiagnosticAudioOwner owner;
  final DiagnosticAudioStage stage;
  final DiagnosticAudioOwner? blockedBy;
  final int request, lease;

  static int _number(Object? value) =>
      value is int ? value.clamp(0, 2147483647) : 0;
  static T _enum<T extends Enum>(List<T> values, Object? value, T fallback) =>
      values.firstWhere((item) => item.name == value, orElse: () => fallback);

  Map<String, Object> toJson() => {
    'owner': owner.name,
    'stage': stage.name,
    'request': _number(request),
    'lease': _number(lease),
    if (blockedBy != null) 'blockedBy': blockedBy!.name,
  };

  factory DiagnosticAudioDetails.fromJson(Map<String, dynamic> json) =>
      DiagnosticAudioDetails(
        owner: _enum(
          DiagnosticAudioOwner.values,
          json['owner'],
          DiagnosticAudioOwner.unknown,
        ),
        stage: _enum(
          DiagnosticAudioStage.values,
          json['stage'],
          DiagnosticAudioStage.unknown,
        ),
        request: _number(json['request']),
        lease: _number(json['lease']),
        blockedBy: json['blockedBy'] == null
            ? null
            : _enum(
                DiagnosticAudioOwner.values,
                json['blockedBy'],
                DiagnosticAudioOwner.unknown,
              ),
      );
}
