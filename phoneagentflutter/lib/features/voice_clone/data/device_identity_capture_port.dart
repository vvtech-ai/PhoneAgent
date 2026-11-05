import '../../../core/diagnostics/clone_diagnostics.dart';
import '../../../core/diagnostics/diagnostic_event.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../domain/clone_verification.dart';

enum IdentityCaptureFailure { unavailable, busy, cancelled, invalidResponse }

/// One explicitly authorized capture session. No SDK calls in construction.
class DeviceIdentityCapturePort implements IdentityCapturePort {
  DeviceIdentityCapturePort({
    this.channel = const MethodChannel('phone_agent/identity_capture'),
    this.diagnostics,
    this.platform,
    this.web,
  }) : _session =
           'identity-${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';
  final CloneDiagnostics? diagnostics;
  final MethodChannel channel;
  final TargetPlatform? platform;
  final bool? web;
  final String _session;
  static int _sequence = 0;
  bool _closed = false, _used = false;
  bool _started = false, _aborted = false;
  Future<void>? _aborting;
  Future<String>? _preparation;
  bool get _supported =>
      !(web ?? kIsWeb) &&
      const {
        TargetPlatform.android,
        TargetPlatform.iOS,
      }.contains(platform ?? defaultTargetPlatform);

  @override
  Future<String> prepare() {
    _check();
    return _preparation ??= _prepare();
  }

  Future<String> _prepare() async {
    _started = true;
    final value = await _invoke('prepare');
    _check();
    if (value is! String || value.trim().isEmpty) {
      throw IdentityCaptureFailure.invalidResponse;
    }
    return value;
  }

  @override
  Future<IdentityCaptureResult> capture(String certifyId) async {
    _check();
    if (_used) throw IdentityCaptureFailure.busy;
    if (_preparation == null ||
        certifyId.trim().isEmpty ||
        certifyId.length > 4096) {
      throw IdentityCaptureFailure.unavailable;
    }
    _used = true;
    await _preparation;
    _check();
    final value = await _invoke('capture', {'certifyId': certifyId});
    _check();
    if (value is! Map ||
        value['code'] is! int ||
        value['reason'] is! String ||
        value['deviceModel'] is! String ||
        value['networkType'] is! String ||
        value['networkValidated'] is! bool) {
      throw IdentityCaptureFailure.invalidResponse;
    }
    return IdentityCaptureResult(
      value['code'] as int,
      reason: value['reason'] as String,
      deviceModel: value['deviceModel'] as String,
      networkType: value['networkType'] as String,
      networkValidated: value['networkValidated'] as bool,
    );
  }

  Future<Object?> _invoke(
    String method, [
    Map<String, Object?> extra = const {},
  ]) async {
    try {
      return await channel.invokeMethod<Object?>(method, {
        'session': _session,
        ...extra,
      });
    } on MissingPluginException catch (error) {
      diagnostics?.failed(_stage(method), error, 0);
      throw IdentityCaptureFailure.unavailable;
    } on PlatformException catch (error) {
      diagnostics?.failed(_stage(method), error, 0);
      throw switch (error.code) {
        'capture_busy' => IdentityCaptureFailure.busy,
        'capture_cancelled' => IdentityCaptureFailure.cancelled,
        _ => IdentityCaptureFailure.unavailable,
      };
    }
  }

  DiagnosticCloneStage _stage(String method) => switch (method) {
    'prepare' => DiagnosticCloneStage.sdkPrepare,
    'capture' => DiagnosticCloneStage.sdkCapture,
    'abort' => DiagnosticCloneStage.sdkAbort,
    _ => DiagnosticCloneStage.sdkRelease,
  };

  void _check() {
    if (_closed) throw IdentityCaptureFailure.cancelled;
    if (!_supported) throw IdentityCaptureFailure.unavailable;
  }

  @override
  Future<void> abort() {
    _closed = true;
    _preparation = null;
    // Never initialize an SDK just to close an unused port.
    if (!_supported || !_started || _aborted) return Future.value();
    return _aborting ??= _abort();
  }

  Future<void> _abort() async {
    try {
      await _invoke('abort');
      _aborted = true;
    } finally {
      _aborting = null;
    }
  }

  /// Cancellation acknowledgement is not evidence that the SDK released media.
  /// This remains callable after abort and does not initialize an unused SDK.
  Future<void> waitForRelease() async {
    if (_supported && _started) await _invoke('waitForRelease');
  }
}
