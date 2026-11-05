enum ClonePreviewStage {
  input,
  source,
  prepare,
  playback,
  event,
  dispose,
  sourceCleanup,
  stop,
  unknown,
}

/// Closed metadata only. No file paths, audio bytes or arbitrary error text.
class DiagnosticClonePreviewDetails {
  DiagnosticClonePreviewDetails({
    required this.stage,
    String container = '',
    String errorCode = '',
    String errorDomain = '',
    this.nativeCode,
    this.byteCount,
    this.wavFormat,
    this.channels,
    this.sampleRate,
    this.bitsPerSample,
    this.dataBytes,
    String nativeStep = '',
    String sessionCategory = '',
    String sessionMode = '',
    this.sessionOptions,
    this.nativeAttempt,
  }) : nativeStep =
           const {'deactivate', 'setCategory', 'setActive'}.contains(nativeStep)
           ? nativeStep
           : '',
       sessionCategory =
           const {
             'playback',
             'playAndRecord',
             'record',
             'ambient',
             'soloAmbient',
             'multiRoute',
             'other',
           }.contains(sessionCategory)
           ? sessionCategory
           : '',
       sessionMode =
           const {
             'default',
             'voiceChat',
             'videoChat',
             'measurement',
             'other',
           }.contains(sessionMode)
           ? sessionMode
           : '',
       container =
           const {
             'wav',
             'mp3',
             'aac',
             'ogg',
             'flac',
             'mp4',
             'unknown',
           }.contains(container)
           ? container
           : 'unknown',
       errorCode =
           const {
             'DarwinAudioError',
             'AudioPlayerError',
             'UnexpectedError',
             'missingPlugin',
             'timeout',
             'state',
             'format',
             'fileSystem',
             'other',
           }.contains(errorCode)
           ? errorCode
           : '',
       errorDomain =
           const {
             'AVFoundationErrorDomain',
             'NSOSStatusErrorDomain',
             'NSCocoaErrorDomain',
           }.contains(errorDomain)
           ? errorDomain
           : '';
  final ClonePreviewStage stage;
  final String container, errorCode, errorDomain;
  final String nativeStep, sessionCategory, sessionMode;
  final int? sessionOptions, nativeAttempt;
  final int? nativeCode,
      byteCount,
      wavFormat,
      channels,
      sampleRate,
      bitsPerSample,
      dataBytes;
  Map<String, Object> toJson() => {
    'stage': stage.name,
    'container': container,
    if (errorCode.isNotEmpty) 'errorCode': errorCode,
    if (errorDomain.isNotEmpty) 'errorDomain': errorDomain,
    if (nativeStep.isNotEmpty) 'nativeStep': nativeStep,
    if (sessionCategory.isNotEmpty) 'sessionCategory': sessionCategory,
    if (sessionMode.isNotEmpty) 'sessionMode': sessionMode,
    if (sessionOptions != null)
      'sessionOptions': sessionOptions!.clamp(0, 2147483647),
    if (nativeAttempt != null) 'nativeAttempt': nativeAttempt!.clamp(1, 3),
    if (nativeCode != null)
      'nativeCode': nativeCode!.clamp(-2147483648, 2147483647),
    for (final e in {
      'byteCount': byteCount,
      'wavFormat': wavFormat,
      'channels': channels,
      'sampleRate': sampleRate,
      'bitsPerSample': bitsPerSample,
      'dataBytes': dataBytes,
    }.entries)
      if (e.value != null) e.key: e.value!.clamp(0, 2147483647),
  };
  factory DiagnosticClonePreviewDetails.fromJson(Map<String, dynamic> json) {
    int? number(String key) => json[key] is int ? json[key] as int : null;
    String text(String key) => json[key] is String ? json[key] as String : '';
    return DiagnosticClonePreviewDetails(
      stage: ClonePreviewStage.values.firstWhere(
        (s) => s.name == json['stage'],
        orElse: () => ClonePreviewStage.unknown,
      ),
      container: text('container'),
      errorCode: text('errorCode'),
      errorDomain: text('errorDomain'),
      nativeCode: number('nativeCode'),
      nativeStep: text('nativeStep'),
      sessionCategory: text('sessionCategory'),
      sessionMode: text('sessionMode'),
      sessionOptions: number('sessionOptions'),
      nativeAttempt: number('nativeAttempt'),
      byteCount: number('byteCount'),
      wavFormat: number('wavFormat'),
      channels: number('channels'),
      sampleRate: number('sampleRate'),
      bitsPerSample: number('bitsPerSample'),
      dataBytes: number('dataBytes'),
    );
  }
}
