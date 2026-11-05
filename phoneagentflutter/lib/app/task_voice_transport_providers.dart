import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/presentation/controller/auth_providers.dart';
import '../features/conversation/data/voice/signed_voice_socket.dart';
import 'business_providers.dart';
import 'request_signing_providers.dart';

final taskVoiceTransportProvider = Provider.autoDispose<SignedVoiceSocket>((
  ref,
) {
  ref.watch(loginEpochProvider);
  return SignedVoiceSocket(
    ref.watch(sessionControllerProvider.notifier),
    ref.watch(requestSigningProvider),
  );
});
