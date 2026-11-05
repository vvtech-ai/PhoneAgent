import '../../../core/diagnostics/diagnostic_event.dart';
import 'trusted_caller_diagnostics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../domain/trusted_caller.dart';
import '../domain/trusted_caller_account.dart';

class DeviceTrustedCallerAccountPort implements TrustedCallerAccountPort {
  const DeviceTrustedCallerAccountPort({
    this.platform,
    this.web,
    this.diagnostics,
  });
  final DiagnosticSink Function()? diagnostics;
  final TargetPlatform? platform;
  final bool? web;
  static const _channel = MethodChannel('phone_agent/trusted_caller');

  @override
  Future<bool> updateAccount(TrustedCallerOwner? owner, String environment) =>
      traceTrustedCaller(
        stage: DiagnosticTrustedCallerStage.accountSync,
        environment: environment,
        platform: platform,
        sink: diagnostics?.call(),
        action: () => _update(owner, environment),
      );

  Future<bool> _update(TrustedCallerOwner? owner, String environment) async {
    if ((web ?? kIsWeb) ||
        !{
          TargetPlatform.iOS,
          TargetPlatform.android,
        }.contains(platform ?? defaultTargetPlatform) ||
        !{'test', 'pro'}.contains(environment) ||
        (owner != null && !owner.valid)) {
      return false;
    }
    try {
      await _channel.invokeMethod<void>('updateAccount', {
        'environment': environment,
        'owner': owner == null
            ? null
            : {
                'accountId': owner.accountId,
                'phone': owner.phone,
                'loginEpoch': owner.loginEpoch,
              },
      });
      // Account delivery does not confirm SDK authorization, SIM or APNS success.
      return true;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (error) {
      throw TrustedCallerFailure(
        DiagnosticTrustedCallerDetails.codes.contains(error.code)
            ? error.code
            : 'SDK_UNKNOWN',
      );
    }
  }
}
