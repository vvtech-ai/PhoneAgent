import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/core/diagnostics/runtime_diagnostic_hooks.dart';

void main() {
  late FlutterExceptionHandler? framework;
  late bool Function(Object, StackTrace)? unhandled;
  final events = <DiagnosticEvent>[];
  setUp(() {
    framework = FlutterError.onError;
    unhandled = PlatformDispatcher.instance.onError;
    FlutterError.onError = null;
    PlatformDispatcher.instance.onError = null;
    events.clear();
  });
  tearDown(() {
    FlutterError.onError = framework;
    PlatformDispatcher.instance.onError = unhandled;
  });

  test('framework details reach previous handler unchanged, no raw data', () {
    FlutterErrorDetails? forwarded;
    FlutterError.onError = (details) => forwarded = details;
    final hooks = RuntimeDiagnosticHooks.install(events.add);
    final details = FlutterErrorDetails(
      exception: PlatformException(
        code: 'synthetic-private-code',
        message: 'synthetic-private-message',
        details: {'token': 'synthetic-private-token'},
      ),
      stack: StackTrace.fromString('synthetic-private-stack'),
    );
    FlutterError.reportError(details);
    expect(forwarded, same(details));
    expect(events.single.operation, DiagnosticOperation.flutterFramework);
    expect(events.single.failureKind, DiagnosticFailureKind.platform);
    expect(events.single.result, DiagnosticResult.failed);
    expect(jsonEncode(events.single.toJson()), isNot(contains('private')));
    expect(events.single.toJson().keys.toSet(), {
      'operation',
      'result',
      'time',
      'statusCode',
      'elapsedMs',
      'failureKind',
    });
    hooks.dispose();
  });

  for (final handled in [false, true]) {
    test('unhandled preserves predecessor result $handled and arguments', () {
      final error = StateError('private');
      final stack = StackTrace.current;
      var calls = 0;
      PlatformDispatcher.instance.onError = (value, trace) {
        expect(value, same(error));
        expect(trace, same(stack));
        calls++;
        return handled;
      };
      final hooks = RuntimeDiagnosticHooks.install(events.add);
      expect(PlatformDispatcher.instance.onError!(error, stack), handled);
      expect(calls, 1);
      expect(events.single.operation, DiagnosticOperation.dartUnhandled);
      hooks.dispose();
    });
  }

  test('no previous handler does not claim errors were handled', () {
    final hooks = RuntimeDiagnosticHooks.install(events.add);
    expect(
      PlatformDispatcher.instance.onError!(_Unprintable(), StackTrace.current),
      isFalse,
    );
    expect(events.single.failureKind, DiagnosticFailureKind.other);
    hooks.dispose();
    expect(PlatformDispatcher.instance.onError, isNull);
    expect(FlutterError.onError, isNull);
  });

  test('fixed classifications round trip; old events remain readable', () {
    final values = <Object, DiagnosticFailureKind>{
      FlutterError('private'): DiagnosticFailureKind.framework,
      MissingPluginException('private'): DiagnosticFailureKind.missingPlugin,
      TimeoutException('private'): DiagnosticFailureKind.timeout,
      const FormatException('private'): DiagnosticFailureKind.format,
      StateError('private'): DiagnosticFailureKind.state,
      ArgumentError('private'): DiagnosticFailureKind.argument,
      AssertionError('private'): DiagnosticFailureKind.assertion,
      _Unprintable(): DiagnosticFailureKind.other,
    };
    final hooks = RuntimeDiagnosticHooks.install(events.add);
    for (final entry in values.entries) {
      PlatformDispatcher.instance.onError!(entry.key, StackTrace.empty);
      final restored = DiagnosticEvent.fromJson(events.last.toJson());
      expect(restored.failureKind, entry.value);
      expect(restored.toJson(), events.last.toJson());
      expect(
        DiagnosticEvent.fromJson(
          events.last.toJson()..remove('failureKind'),
        ).failureKind,
        isNull,
      );
    }
    hooks.dispose();
  });

  test('sink failure does not replace previous handler exception', () {
    final original = StateError('original');
    FlutterError.onError = (_) => throw original;
    PlatformDispatcher.instance.onError = (_, _) => throw original;
    final hooks = RuntimeDiagnosticHooks.install((_) => throw _Unprintable());
    expect(
      () =>
          FlutterError.onError!(FlutterErrorDetails(exception: _Unprintable())),
      throwsA(same(original)),
    );
    expect(
      () => PlatformDispatcher.instance.onError!(
        _Unprintable(),
        StackTrace.empty,
      ),
      throwsA(same(original)),
    );
    hooks.dispose();
  });

  test('sink reentry is bounded and still forwards each error', () {
    var forwards = 0;
    FlutterError.onError = (_) => forwards++;
    final hooks = RuntimeDiagnosticHooks.install((event) {
      events.add(event);
      FlutterError.reportError(FlutterErrorDetails(exception: _Unprintable()));
    });
    FlutterError.reportError(FlutterErrorDetails(exception: _Unprintable()));
    expect(events.length, 1);
    expect(forwards, 2);
    hooks.dispose();
  });

  test('dispose preserves later owner; saved callbacks stop collecting', () {
    var forwards = 0;
    FlutterError.onError = (_) => forwards++;
    final hooks = RuntimeDiagnosticHooks.install(events.add);
    final saved = FlutterError.onError!;
    void later(FlutterErrorDetails _) {}
    bool laterUnhandled(Object _, StackTrace _) => true;
    FlutterError.onError = later;
    PlatformDispatcher.instance.onError = laterUnhandled;
    hooks.dispose();
    hooks.dispose();
    expect(FlutterError.onError, same(later));
    expect(PlatformDispatcher.instance.onError, same(laterUnhandled));
    saved(FlutterErrorDetails(exception: _Unprintable()));
    expect(events, isEmpty);
    expect(forwards, 1);
  });
}

class _Unprintable {
  @override
  String toString() => throw StateError('must not inspect exception text');
}
