/// Synthetic v65 Gson shape; no real account, transcript, or recording grant.
Map<String, Object?> legacyTranslation({String stage = 'READY_TO_ARCHIVE'}) => {
  'accountId': 'a',
  'route': 'WORLD_CALL',
  'stage': stage,
  'identity': {
    'clientCallId': 'legacy-call',
    'phoneAgentCallId': 'old-receipt',
    'worldCallLocator': {
      'clusterId': 'JP',
      'callSessionId': 'synthetic-session',
      'recordingAccessGrant': 'synthetic-grant',
    },
  },
  'targetName': '合成目标',
  'phoneNumber': '+12025550123',
  'myLanguage': 'zh',
  'peerLanguage': 'en',
  'connectedAtMs': 1000,
  'lastObservedAtMs': 1500,
  if (stage != 'CONNECTED') 'endedAtMs': 1500,
  'transcripts': [
    {
      'segmentId': 'segment-1',
      'sourceLeg': 'user',
      'sourceLanguage': 'zh',
      'sourceText': '合成文字',
      'translatedLanguage': 'en',
      'translatedText': 'synthetic text',
      'final': true,
    },
  ],
  'domesticPcmPath': 'must-not-copy',
  'mediaToken': 'must-not-copy',
};
