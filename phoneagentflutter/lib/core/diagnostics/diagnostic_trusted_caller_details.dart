enum DiagnosticTrustedCallerStage {
  accountSync,
  prepare,
  guide,
  open,
  refresh,
  release,
  incomingReceive,
  incomingPayload,
  incomingCache,
  incomingVerify,
  incomingDelivery,
  incomingStream,
  incomingPresentation,
  incomingActivity,
  incomingAvatar,
  pushRegistration,
  pushBinding,
}

enum DiagnosticTrustedCallerPlatform { android, ios, other }

enum DiagnosticTrustedCallerEnvironment { test, pro, other }

/// Bounded metadata only; never accepts native messages or identity fields.
class DiagnosticTrustedCallerDetails {
  const DiagnosticTrustedCallerDetails(
    this.stage,
    this.platform,
    this.environment, {
    this.code = '',
    this.errorDomain,
    this.errorCode,
  });
  final DiagnosticTrustedCallerStage stage;
  final DiagnosticTrustedCallerPlatform platform;
  final DiagnosticTrustedCallerEnvironment environment;
  final String code;
  final String? errorDomain;
  final int? errorCode;
  static const errorDomains = {
    'NSCocoaErrorDomain',
    'NSURLErrorDomain',
    'NSPOSIXErrorDomain',
    'other',
  };
  bool get _isAPNSFailure =>
      platform == DiagnosticTrustedCallerPlatform.ios &&
      stage == DiagnosticTrustedCallerStage.pushRegistration &&
      code == 'IOS_APNS_REGISTRATION_FAILED';
  static int? boundedErrorCode(Object? value) =>
      value is int && value >= -2147483648 && value <= 2147483647
      ? value
      : null;
  static const codes = {
    'IOS_PUSH_FOREGROUND',
    'IOS_PUSH_BACKGROUND',
    'IOS_PUSH_CLICK',
    'IOS_PUSH_COLD',
    'IOS_PAYLOAD_ACCEPTED',
    'IOS_PAYLOAD_REJECTED',
    'IOS_OWNER_MISSING',
    'IOS_OWNER_STALE',
    'IOS_CACHE_STORED',
    'IOS_CACHE_RECOVERED',
    'IOS_CACHE_EXPIRED',
    'IOS_CACHE_REJECTED',
    'IOS_VERIFY_STARTED',
    'IOS_VERIFY_SUCCEEDED',
    'IOS_VERIFY_FAILED',
    'IOS_VERIFY_UNCERTIFIED',
    'IOS_EVENT_PUBLISHED',
    'IOS_EVENT_CLEARED',
    'IOS_EVENT_DUPLICATE',
    'IOS_EVENT_REOPENED',
    'IOS_ACTIVITY_STARTED',
    'IOS_ACTIVITY_UPDATED',
    'IOS_ACTIVITY_ENDED',
    'IOS_ACTIVITY_FAILED',
    'IOS_ACTIVITY_DISABLED',
    'IOS_ACTIVITY_BACKGROUND_DEFERRED',
    'IOS_ACTIVITY_RETRY_EXHAUSTED',
    'IOS_ACTIVITY_INELIGIBLE',
    'IOS_ACTIVITY_SIZE_REJECTED',
    'IOS_AVATAR_SUCCEEDED',
    'IOS_AVATAR_FALLBACK',
    'IOS_APNS_ALLOWED',
    'IOS_APNS_DENIED',
    'IOS_APNS_TOKEN_RECEIVED',
    'IOS_APNS_REGISTRATION_FAILED',
    'IOS_APNS_CONFIG_MISSING',
    'IOS_APNS_CONFIG_MISMATCH',
    'IOS_APNS_REGISTER_REQUESTED',
    'IOS_APNS_REGISTER_RETURNED',
    'IOS_APNS_CALLBACK_PENDING',
    'IOS_APNS_TOKEN_CALLBACK',
    'IOS_APNS_TOKEN_REJECTED',
    'IOS_BIND_WAIT_OWNER',
    'IOS_BIND_WAIT_PERMISSION',
    'IOS_BIND_WAIT_TOKEN',
    'IOS_SDK_INIT_STARTED',
    'IOS_SDK_INIT_SUCCEEDED',
    'IOS_SDK_INIT_FAILED',
    'IOS_BIND_WAIT_RETRY',
    'IOS_BIND_STARTED',
    'IOS_BIND_STATE_CONFIRMED',
    'IOS_BIND_STATE_PENDING',
    'IOS_BIND_STATE_UNCERTAIN',
    'IOS_BIND_STATE_UNCONFIRMED',
    'IOS_BIND_STATE_INIT_FAILED',
    'IOS_BIND_STATE_INITIALIZING',
    'IOS_BIND_SUCCEEDED',
    'IOS_BIND_FAILED',
    'IOS_UNBIND_STARTED',
    'IOS_UNBIND_SUCCEEDED',
    'IOS_UNBIND_FAILED',
    'IOS_STREAM_STARTED',
    'IOS_STREAM_FAILED',
    'IOS_STREAM_RETRY',
    'IOS_STREAM_EXHAUSTED',
    'IOS_DTO_REJECTED',
    'IOS_PRESENTED',
    'IOS_PRESENTATION_DEFERRED',
    'IOS_PRESENTATION_CLEARED',
    'IOS_PRESENTATION_DISMISSED',

    'SDK_ACCOUNT_INVALID',
    'SDK_ACCOUNT_UNCONFIRMED',
    'SDK_PREPARE_FAILED',
    'SDK_RUNTIME_MISSING',
    'SDK_CREDENTIALS_MISSING',
    'SDK_RUNTIME_LINKAGE_FAILED',
    'SDK_INITIALIZATION_EXCEPTION',
    'SDK_SURFACE_INVALID',
    'SDK_SURFACE_BUSY',
    'SDK_SURFACE_CLOSED',
    'SDK_NOT_CONFIGURED',
    'SDK_UNAVAILABLE',
    'SDK_INVALID_REPORT',
    'SDK_OPERATION_FAILED',
    'SDK_RELEASE_FAILED',
    'SDK_GUIDE_REQUIRED',
    'SDK_GUIDE_UNAVAILABLE',
    'SDK_PHONE_INVALID',
    'SDK_OPEN_FAILED',
    'SDK_SIM_SYNC_UNCONFIRMED',
    'SDK_SIM_CLEANUP_UNCONFIRMED',
    'SDK_INCOMING_CLEANUP_UNCONFIRMED',
    'SDK_LAUNCH_UNCONFIRMED',
    'SDK_TIMEOUT',
    'SDK_UNKNOWN',
  };
  Map<String, Object> toJson() => {
    'stage': stage.name,
    'platform': platform.name,
    'environment': environment.name,
    if (code.isNotEmpty) 'code': codes.contains(code) ? code : 'SDK_UNKNOWN',
    if (_isAPNSFailure && errorDomain != null)
      'errorDomain': errorDomains.contains(errorDomain)
          ? errorDomain!
          : 'other',
    if (_isAPNSFailure && boundedErrorCode(errorCode) != null)
      'errorCode': errorCode!,
  };
  factory DiagnosticTrustedCallerDetails.fromJson(Map<String, dynamic> json) =>
      DiagnosticTrustedCallerDetails(
        DiagnosticTrustedCallerStage.values.byName(json['stage'] as String),
        DiagnosticTrustedCallerPlatform.values.byName(
          json['platform'] as String,
        ),
        DiagnosticTrustedCallerEnvironment.values.byName(
          json['environment'] as String,
        ),
        errorDomain: json['errorDomain'] is String
            ? (errorDomains.contains(json['errorDomain'])
                  ? json['errorDomain'] as String
                  : 'other')
            : null,
        errorCode: boundedErrorCode(json['errorCode']),
        code: json['code'] is String && codes.contains(json['code'])
            ? json['code'] as String
            : '',
      );
}
