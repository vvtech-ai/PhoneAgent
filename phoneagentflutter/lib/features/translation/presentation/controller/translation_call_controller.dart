import '../../domain/translation_call_view.dart';

/// Shared presentation contract; transport-specific coordinators stay separate.
abstract interface class TranslationCallController {
  TranslationCallView get snapshot;
  void Function() addListener(
    void Function(TranslationCallView) listener, {
    bool fireImmediately = true,
  });
  Future<void> start();
  Future<void> mute();
  Future<void> speaker();
  void dialPad();
  Future<void> digit(String digit);
  Future<void> hangup();
  void dispose();
}
