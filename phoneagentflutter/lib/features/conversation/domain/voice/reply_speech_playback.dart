enum ReplySpeechPhase { accepting, draining, completed, cancelled, failed }

abstract interface class ReplySpeechPlayback {
  ReplySpeechPhase get phase;
  bool get synthesizing;
  bool get hasPendingText;
  int get queuedBytes;
  int get failures;

  /// True only when this playback accepted the text for synthesis.
  bool enqueue(String text);
  void complete();
  Future<void> cancel();
}

typedef ReplySpeechFactory =
    ReplySpeechPlayback Function(
      bool Function() isCurrent,
      void Function() onChanged,
    );
