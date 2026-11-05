import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/tools/conversation_permission.dart';
import 'package:phone_agent/features/translation/domain/translation_dial_preflight.dart';
import '../conversation/voice/voice_input_fake.dart';

class GrantAfterRequest extends InputPermissionFake {
  @override
  Future<PermissionGrant> resolve(
    ConversationPermission permission, {
    required bool request,
  }) async {
    expect(permission, ConversationPermission.microphone);
    requests.add(request);
    return request ? PermissionGrant.granted : PermissionGrant.denied;
  }
}

void main() {
  test(
    'already granted is read-only; denied requests once and can proceed',
    () async {
      final granted = InputPermissionFake(), request = GrantAfterRequest();
      await ensureTranslationMicrophone(granted, () => true);
      await ensureTranslationMicrophone(request, () => true);
      expect(granted.requests, [false]);
      expect(request.requests, [false, true]);
    },
  );
  test(
    'denied and unavailable fail explicitly without repeated prompts',
    () async {
      for (final grant in [
        PermissionGrant.denied,
        PermissionGrant.unavailable,
      ]) {
        final source = InputPermissionFake()..grant = grant;
        await expectLater(
          ensureTranslationMicrophone(source, () => true),
          throwsA(
            grant == PermissionGrant.denied
                ? TranslationDialPreflightFailure.microphoneDenied
                : TranslationDialPreflightFailure.microphoneUnavailable,
          ),
        );
        expect(
          source.requests,
          grant == PermissionGrant.denied ? [false, true] : [false],
        );
      }
    },
  );
  test(
    'account cancellation prevents a late denied result from opening prompt',
    () async {
      var current = true;
      final source = InputPermissionFake()..gate = Completer<PermissionGrant>();
      final work = ensureTranslationMicrophone(source, () => current);
      current = false;
      final assertion = expectLater(work, throwsStateError);
      source.gate!.complete(PermissionGrant.denied);
      await assertion;
      expect(source.requests, [false]);
    },
  );
}
