import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'diagnostic_event.dart';

/// Observes main-isolate failures without changing the existing error policy.
/// Never serializes the exception, its details, or its stack trace.
class RuntimeDiagnosticHooks {
  RuntimeDiagnosticHooks.install(this._sink)
    : _previousFramework = FlutterError.onError,
      _previousUnhandled = PlatformDispatcher.instance.onError {
    _framework = (details) {
      _record(DiagnosticOperation.flutterFramework, details.exception);
      _previousFramework?.call(details);
    };
    _unhandled = (error, stack) {
      _record(DiagnosticOperation.dartUnhandled, error);
      return _previousUnhandled?.call(error, stack) ?? false;
    };
    FlutterError.onError = _framework;
    PlatformDispatcher.instance.onError = _unhandled;
  }

  final DiagnosticSink _sink;
  final FlutterExceptionHandler? _previousFramework;
  final bool Function(Object, StackTrace)? _previousUnhandled;
  late final FlutterExceptionHandler _framework;
  late final bool Function(Object, StackTrace) _unhandled;
  bool _active = true, _recording = false;

  void _record(DiagnosticOperation operation, Object error) {
    if (!_active || _recording) return;
    _recording = true;
    try {
      emitDiagnostic(
        _sink,
        DiagnosticEvent(
          operation: operation,
          result: DiagnosticResult.failed,
          failureKind: _kind(error),
        ),
      );
    } finally {
      _recording = false;
    }
  }

  static DiagnosticFailureKind _kind(Object error) => switch (error) {
    FlutterError() => DiagnosticFailureKind.framework,
    MissingPluginException() => DiagnosticFailureKind.missingPlugin,
    PlatformException() => DiagnosticFailureKind.platform,
    TimeoutException() => DiagnosticFailureKind.timeout,
    FormatException() => DiagnosticFailureKind.format,
    StateError() => DiagnosticFailureKind.state,
    ArgumentError() => DiagnosticFailureKind.argument,
    AssertionError() => DiagnosticFailureKind.assertion,
    _ => DiagnosticFailureKind.other,
  };

  void dispose() {
    if (!_active) return;
    _active = false;
    if (identical(FlutterError.onError, _framework)) {
      FlutterError.onError = _previousFramework;
    }
    if (identical(PlatformDispatcher.instance.onError, _unhandled)) {
      PlatformDispatcher.instance.onError = _previousUnhandled;
    }
  }
}
