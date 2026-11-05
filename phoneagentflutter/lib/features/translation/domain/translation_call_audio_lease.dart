/// One explicit active translation. Hardware stops before this lease releases.
abstract interface class TranslationCallAudioLease {
  String get id;
  Future<void> acquire();
  Future<void> release();
}
