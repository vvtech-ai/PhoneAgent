import 'package:flutter/services.dart';
import '../domain/trusted_caller.dart';
import '../domain/trusted_caller_home_guide.dart';

class DeviceTrustedCallerHomeGuideStore implements TrustedCallerHomeGuideStore {
  const DeviceTrustedCallerHomeGuideStore(this.environment);
  final String environment;
  static const _channel = MethodChannel('phone_agent/trusted_caller');

  Map<String, Object> _arguments(TrustedCallerOwner owner) => {
    // No SDK presentation is opened or owned by this preference request.
    'surfaceToken': '00000000000000000000000000000000',
    'accountId': owner.accountId,
    'phone': owner.phone,
    'loginEpoch': owner.loginEpoch,
    'environment': environment,
  };

  @override
  Future<bool> eligible(TrustedCallerOwner owner) async =>
      await _channel.invokeMethod<bool>('readHomeGuide', _arguments(owner)) ==
      true;

  @override
  Future<void> record(TrustedCallerOwner owner, {required bool disabled}) =>
      _channel.invokeMethod<void>('recordHomeGuide', {
        ..._arguments(owner),
        'disabled': disabled,
      });
}
