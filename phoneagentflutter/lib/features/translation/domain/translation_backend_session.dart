class TranslationCreateRequest {
  const TranslationCreateRequest({
    required this.phone,
    required this.userLanguage,
    required this.merchantLanguage,
    required this.provider,
    required this.userId,
    this.originalAudioEnabled = false,
    this.originalAudioPercent = 0,
    this.originalAudioVolumePercent = 100,
  });
  final String phone, userLanguage, merchantLanguage, provider, userId;
  final bool originalAudioEnabled;
  final int originalAudioPercent, originalAudioVolumePercent;

  TranslationCreateRequest withLanguages(String user, String merchant) =>
      TranslationCreateRequest(
        phone: phone,
        userLanguage: user,
        merchantLanguage: merchant,
        provider: provider,
        userId: userId,
        originalAudioEnabled: originalAudioEnabled,
        originalAudioPercent: originalAudioPercent,
        originalAudioVolumePercent: originalAudioVolumePercent,
      );

  Map<String, Object?> toJson() {
    if (!RegExp(r'^\+[1-9][0-9]{3,14}$').hasMatch(phone) ||
        userLanguage.trim().isEmpty ||
        merchantLanguage.trim().isEmpty ||
        userId.trim().isEmpty ||
        !const {'OPENAI', 'GEMINI', 'QWEN'}.contains(provider)) {
      throw const FormatException('Invalid overseas translation request');
    }
    return {
      'merchantPhone': phone,
      'userLanguage': userLanguage,
      'merchantLanguage': merchantLanguage,
      'scene': 'phone_translation',
      'voiceProvider': 'twilio',
      'realtimeProvider': switch (provider) {
        'OPENAI' => 'openai',
        'QWEN' => 'qwen3.5-livetranslate-flash-realtime',
        _ => 'google-gemini-live-translate',
      },
      'capabilities': {
        'mediaTransports': ['livekit', 'websocket'],
      },
      'originalAudioEnabled': originalAudioEnabled,
      'originalAudioPercent': originalAudioEnabled
          ? originalAudioPercent.clamp(0, 50)
          : 0,
      'originalAudioVolumePercent': originalAudioVolumePercent.clamp(0, 100),
    };
  }
}

class TranslationLiveKitConnection {
  const TranslationLiveKitConnection({
    required this.url,
    required this.token,
    this.roomName = '',
    this.participantIdentity = '',
  });
  final String url, token, roomName, participantIdentity;
}

class TranslationBackendSession {
  const TranslationBackendSession({
    required this.id,
    required this.clusterId,
    required this.recordingAccessGrant,
    required this.mediaTransport,
    this.appAudioWsUrl = '',
    this.liveKit,
    this.voiceProvider = 'twilio',
    this.realtimeProvider = '',
    this.environment = const {},
  });
  final String id,
      clusterId,
      recordingAccessGrant,
      mediaTransport,
      appAudioWsUrl,
      voiceProvider,
      realtimeProvider;
  final TranslationLiveKitConnection? liveKit;
  final Map<String, Object?> environment;
}

class TranslationMerchantResult {
  const TranslationMerchantResult(this.started, {this.environment = const {}});
  final bool started;
  final Map<String, Object?> environment;
}

class TranslationBackendFailure implements Exception {
  const TranslationBackendFailure(
    this.code, {
    this.status,
    this.environment = const {},
  });
  final String code;
  final int? status;
  final Map<String, Object?> environment;
  bool get mediaNotReady =>
      status == 409 && code.toUpperCase() == 'MEDIA_CHANNEL_NOT_READY';
}

abstract interface class TranslationBackendRepository {
  Future<TranslationBackendSession> create(TranslationCreateRequest request);
  Future<TranslationMerchantResult> startMerchant(
    TranslationBackendSession session,
    TranslationCreateRequest request,
  );
  Future<void> hangup(TranslationBackendSession session, String userId);
}
