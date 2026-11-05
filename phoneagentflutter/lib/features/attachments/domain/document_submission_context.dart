import '../../contacts/domain/contact_name_matcher.dart';

/// Selection identity and interaction source for one asynchronous document turn.
class DocumentSubmissionContext {
  const DocumentSubmissionContext({
    required this.sessionId,
    required this.generation,
    required this.voiceMode,
    required this.initialSource,
  });
  final String sessionId;
  final int generation;
  final bool voiceMode;
  final ContactInputSource initialSource;

  bool accepts(String currentSessionId, int currentGeneration) =>
      sessionId == currentSessionId && generation == currentGeneration;

  ContactInputSource submissionSource(
    ContactInputSource currentSource, {
    required bool voiceMode,
  }) {
    if (voiceMode != this.voiceMode) {
      return voiceMode ? ContactInputSource.asr : ContactInputSource.typed;
    }
    return currentSource == initialSource
        ? (voiceMode ? ContactInputSource.asr : ContactInputSource.typed)
        : currentSource;
  }
}
