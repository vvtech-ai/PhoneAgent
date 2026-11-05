import 'clone_verification.dart';

/// v65 SDK code policy. No arbitrary SDK reason survives this boundary.
abstract final class CloneSdkDiagnosis {
  static bool requiresServerQuery(int code) => code == 1000 || code == 2006;
  static final _subCode = RegExp(
    r'(^|[^A-Z0-9_])([ZA]\d{4}(?:_\d+)?)(?![A-Z0-9_])',
  );
  static const networks = {
    'VPN',
    'WIFI',
    'CELLULAR',
    'ETHERNET',
    'OTHER',
    'NONE',
  };
  static const _categories = <String, String>{
    'Z1019': 'CAMERA_PERMISSION',
    'Z1030': 'MICROPHONE_PERMISSION',
    'Z1002': 'CAMERA_OPEN',
    'Z1020': 'CAMERA_OPEN',
    'Z1021': 'CAMERA_OPEN',
    'Z1032': 'MICROPHONE_OPEN',
    'Z1001': 'SDK_INITIALIZATION',
    'Z1035': 'SDK_INITIALIZATION',
    'Z1036': 'SDK_INITIALIZATION',
    'Z1024': 'DUPLICATE_FLOW',
    'Z1037': 'CERTIFY_ID_INVALID',
    'Z1003': 'DEVICE_UNSUPPORTED',
    'Z1004': 'DEVICE_UNSUPPORTED',
    'Z1018': 'DEVICE_UNSUPPORTED',
    'Z1029': 'DEVICE_UNSUPPORTED',
    'Z1011': 'NETWORK_INITIALIZATION',
    'Z1025': 'NETWORK_INITIALIZATION',
    'Z1012': 'NETWORK_ACCESS',
    'Z1027': 'NETWORK_ACCESS',
    'Z1040': 'NETWORK_ACCESS',
    'Z1026': 'NETWORK_UPLOAD',
    'Z5112': 'NETWORK_UPLOAD',
    'Z5113': 'NETWORK_UPLOAD',
    'Z5114': 'NETWORK_UPLOAD',
    'Z5116': 'NETWORK_UPLOAD',
    'Z6002': 'NETWORK_UPLOAD',
    'Z1028': 'PROVIDER_BUSY',
    'Z1000': 'SDK_INTERNAL',
    'Z1023': 'SDK_INTERNAL',
    'Z7001': 'SDK_INTERNAL',
    'A4001': 'SDK_INTERNAL',
    'A4005': 'SDK_INTERNAL',
  };
  static final categories = Set<String>.unmodifiable({
    ..._categories.values,
    'SUCCESS',
    'VERIFICATION_REJECTED',
    'USER_CANCELLED',
    'DEVICE_TIME',
    'UNKNOWN',
  });

  static VerificationObservation observation(
    IdentityCaptureResult result,
    Duration elapsed,
  ) {
    final subCode = _subCode.firstMatch(result.reason.toUpperCase())?.group(2);
    final category =
        _categories[subCode] ??
        switch (result.code) {
          1000 => 'SUCCESS',
          1003 => 'USER_CANCELLED',
          2002 => 'NETWORK_ACCESS',
          2003 => 'DEVICE_TIME',
          2006 => 'VERIFICATION_REJECTED',
          1001 => 'SDK_INTERNAL',
          _ => 'UNKNOWN',
        };
    var device = result.deviceModel.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (device.isEmpty) device = 'unknown';
    if (device.length > 64) device = device.substring(0, 64);
    return VerificationObservation(
      deviceModel: device,
      networkType: networks.contains(result.networkType)
          ? result.networkType
          : 'NONE',
      networkValidated: result.networkValidated,
      sdkCode: result.code >= -1 && result.code <= 9999 ? result.code : -1,
      sdkSubCode: subCode,
      reasonCategory: category,
      sdkElapsedMs: elapsed.inMilliseconds.clamp(0, 3600000),
    );
  }
}
