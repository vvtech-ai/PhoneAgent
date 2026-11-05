import '../../../core/diagnostics/diagnostic_event.dart';
import 'trusted_caller_diagnostics.dart';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../domain/trusted_caller.dart';

/// One presentation, independent of the account's incoming-call registration.
class DeviceTrustedCallerPort
    implements
        TrustedCallerPort,
        TrustedCallerGuidePort,
        TrustedCallerEntryPort {
  DeviceTrustedCallerPort({
    required this.sdkEnvironment,
    this.channel = const MethodChannel('phone_agent/trusted_caller'),
    this.platform,
    this.web,
    this.diagnostics,
  }) : _surfaceToken = List.generate(
         16,
         (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
       ).join();

  final String sdkEnvironment;
  final MethodChannel channel;
  final TargetPlatform? platform;
  final bool? web;
  final DiagnosticSink? diagnostics;
  final String _surfaceToken;
  TrustedCallerOwner? _owner;
  bool _released = false, _prepared = false;
  bool? _needsIntroduction;

  @override
  bool get needsIntroduction {
    if (!_prepared || _released) {
      throw const TrustedCallerFailure('SDK_NOT_CONFIGURED');
    }
    if ((platform ?? defaultTargetPlatform) != TargetPlatform.iOS) return false;
    return _needsIntroduction ??
        (throw const TrustedCallerFailure('SDK_INVALID_REPORT'));
  }

  bool get _supported =>
      !(web ?? kIsWeb) &&
      const {
        TargetPlatform.android,
        TargetPlatform.iOS,
      }.contains(platform ?? defaultTargetPlatform);

  @override
  Future<bool> prepare(TrustedCallerOwner owner) async {
    _checkOwner(owner);
    _owner ??= owner;
    _prepared = false;
    if (!_supported || !const {'test', 'pro'}.contains(sdkEnvironment)) {
      return false;
    }
    try {
      final report = await _request('prepare', owner);
      final guide = report['needsIntroduction'];
      if (guide != null && guide is! bool) {
        throw const TrustedCallerFailure('SDK_INVALID_REPORT');
      }
      _needsIntroduction = guide as bool?;
      _prepared =
          report['linked'] == true &&
          report['configured'] == true &&
          report['environment'] == sdkEnvironment;
      return _prepared;
    } on TrustedCallerFailure catch (failure) {
      if (failure.code == 'SDK_UNAVAILABLE') return false;
      rethrow;
    } catch (_) {
      throw const TrustedCallerFailure('SDK_PREPARE_FAILED');
    }
  }

  @override
  Future<TrustedCallerReport> readStatus(TrustedCallerOwner owner) async {
    _requirePrepared(owner);
    final value = await _request('readStatus', owner);
    final statusName = value['status'];
    final status = TrustedCallerStatus.values.where(
      (status) => status.name == statusName,
    );
    final explicit = value['explicitSdkAuthorization'];
    final introduction = value['needsIntroduction'];
    if (introduction != null && introduction is! bool) {
      throw const TrustedCallerFailure('SDK_INVALID_REPORT');
    }
    if (status.length != 1 ||
        explicit is! bool ||
        (status.single == TrustedCallerStatus.authorized && !explicit)) {
      throw const TrustedCallerFailure('SDK_INVALID_REPORT');
    }
    return TrustedCallerReport(
      owner: owner,
      status: status.single,
      explicitSdkAuthorization: explicit,
      needsIntroduction: introduction == true,
    );
  }

  @override
  Future<void> openSettings(TrustedCallerOwner owner) async {
    _requirePrepared(owner);
    // Android acknowledges launch dispatch; iOS waits for this surface to exit.
    await _request('openSettings', owner);
  }

  @override
  Future<void> markIntroductionSeen(TrustedCallerOwner owner) async {
    _requirePrepared(owner);
    final report = await _request('markIntroductionSeen', owner);
    if (report['needsIntroduction'] != false) {
      throw const TrustedCallerFailure('SDK_INVALID_REPORT');
    }
  }

  @override
  Future<void> releaseSurface(TrustedCallerOwner owner) async {
    if (_released) return;
    _checkOwner(owner);
    _released = true;
    _prepared = false;
    if (!_supported || _owner == null) return;
    try {
      await traceTrustedCaller<void>(
        stage: DiagnosticTrustedCallerStage.release,
        environment: sdkEnvironment,
        platform: platform,
        sink: diagnostics,
        action: () async {
          try {
            await channel.invokeMethod<void>(
              'releaseSurface',
              _arguments(owner),
            );
          } on PlatformException catch (error) {
            throw TrustedCallerFailure(
              DiagnosticTrustedCallerDetails.codes.contains(error.code)
                  ? error.code
                  : 'SDK_RELEASE_FAILED',
            );
          }
        },
      );
    } on TrustedCallerFailure {
      rethrow;
    } catch (_) {
      throw const TrustedCallerFailure('SDK_RELEASE_FAILED');
    }
  }

  void _checkOwner(TrustedCallerOwner owner) {
    if (_released ||
        !owner.valid ||
        (_owner != null && !_owner!.matches(owner))) {
      throw const TrustedCallerFailure('SDK_SURFACE_INVALID');
    }
  }

  void _requirePrepared(TrustedCallerOwner owner) {
    _checkOwner(owner);
    if (!_prepared) throw const TrustedCallerFailure('SDK_NOT_CONFIGURED');
  }

  Map<String, Object> _arguments(TrustedCallerOwner owner) => {
    'surfaceToken': _surfaceToken,
    'accountId': owner.accountId,
    'phone': owner.phone,
    'loginEpoch': owner.loginEpoch,
    'environment': sdkEnvironment,
  };

  Future<Map<String, Object?>> _request(
    String method,
    TrustedCallerOwner owner,
  ) => traceTrustedCaller(
    stage: switch (method) {
      'prepare' => DiagnosticTrustedCallerStage.prepare,
      'readStatus' => DiagnosticTrustedCallerStage.refresh,
      'markIntroductionSeen' => DiagnosticTrustedCallerStage.guide,
      _ => DiagnosticTrustedCallerStage.open,
    },
    environment: sdkEnvironment,
    platform: platform,
    sink: diagnostics,
    action: () => _requestNative(method, owner),
  );

  Future<Map<String, Object?>> _requestNative(
    String method,
    TrustedCallerOwner owner,
  ) async {
    _checkOwner(owner);
    Map<String, Object?>? value;
    try {
      value = await channel.invokeMapMethod<String, Object?>(
        method,
        _arguments(owner),
      );
    } on MissingPluginException {
      throw const TrustedCallerFailure('SDK_UNAVAILABLE');
    } on PlatformException catch (error) {
      throw TrustedCallerFailure(
        DiagnosticTrustedCallerDetails.codes.contains(error.code)
            ? error.code
            : 'SDK_UNKNOWN',
      );
    } catch (_) {
      throw const TrustedCallerFailure('SDK_OPERATION_FAILED');
    }
    _checkOwner(owner);
    if (value == null ||
        value['surfaceToken'] != _surfaceToken ||
        value['accountId'] != owner.accountId ||
        value['phone'] != owner.phone ||
        value['loginEpoch'] != owner.loginEpoch ||
        value['environment'] != sdkEnvironment) {
      throw const TrustedCallerFailure('SDK_INVALID_REPORT');
    }
    // Android capability rejection must be inside the traced request: a returned
    // map alone is not successful SDK preparation. Keep iOS semantics unchanged.
    if (method == 'prepare' &&
        (platform ?? defaultTargetPlatform) == TargetPlatform.android) {
      if (value['linked'] != true) {
        throw const TrustedCallerFailure('SDK_RUNTIME_MISSING');
      }
      if (value['configured'] != true) {
        throw const TrustedCallerFailure('SDK_NOT_CONFIGURED');
      }
    }
    return value;
  }
}
