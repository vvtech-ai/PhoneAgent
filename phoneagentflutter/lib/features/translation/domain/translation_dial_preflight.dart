import '../../conversation/domain/tools/conversation_permission.dart';

enum TranslationDialPreflightFailure { microphoneDenied, microphoneUnavailable }

/// Called only after an explicit, validated dial action; never starts capture.
Future<void> ensureTranslationMicrophone(
  ConversationPermissionSource source,
  bool Function() current,
) async {
  void check() {
    if (!current()) throw StateError('Translation preparation cancelled');
  }

  check();
  var grant = await source.resolve(
    ConversationPermission.microphone,
    request: false,
  );
  check();
  if (grant == PermissionGrant.denied) {
    grant = await source.resolve(
      ConversationPermission.microphone,
      request: true,
    );
    check();
  }
  if (grant == PermissionGrant.denied) {
    throw TranslationDialPreflightFailure.microphoneDenied;
  }
  if (grant != PermissionGrant.granted) {
    throw TranslationDialPreflightFailure.microphoneUnavailable;
  }
}
