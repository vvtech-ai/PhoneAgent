import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import '../network/account_session.dart';
import 'diagnostic_event.dart';

class CloneDiagnostics {
  CloneDiagnostics(this.sink, {String? sessionId, String? platform})
    : sessionId = sessionId ?? _id(),
      platform = platform ?? (kIsWeb ? 'web' : defaultTargetPlatform.name);
  static final _zoneKey = Object();
  static CloneDiagnostics? get current =>
      Zone.current[_zoneKey] as CloneDiagnostics?;
  final DiagnosticSink? sink;
  final String sessionId, platform;

  Future<T> run<T>(
    DiagnosticCloneStage stage,
    Future<T> Function() action, {
    String Function(T)? state,
  }) async {
    final watch = Stopwatch()..start();
    event(stage, DiagnosticResult.started);
    try {
      final value = await runZoned(action, zoneValues: {_zoneKey: this});
      event(
        stage,
        DiagnosticResult.succeeded,
        elapsedMs: watch.elapsedMilliseconds,
        state: state?.call(value) ?? '',
      );
      return value;
    } catch (error) {
      failed(stage, error, watch.elapsedMilliseconds);
      rethrow;
    }
  }

  T sync<T>(DiagnosticCloneStage stage, T Function() action) {
    final watch = Stopwatch()..start();
    event(stage, DiagnosticResult.started);
    try {
      final value = runZoned(action, zoneValues: {_zoneKey: this});
      event(
        stage,
        DiagnosticResult.succeeded,
        elapsedMs: watch.elapsedMilliseconds,
      );
      return value;
    } catch (error) {
      failed(stage, error, watch.elapsedMilliseconds);
      rethrow;
    }
  }

  void failed(DiagnosticCloneStage stage, Object error, int elapsedMs) => event(
    stage,
    DiagnosticResult.failed,
    reason: reason(error),
    elapsedMs: elapsedMs,
    statusCode: switch (error) {
      ApiHttpFailure() => error.statusCode,
      ApiCodeFailure() => error.statusCode,
      _ => 0,
    },
  );

  void event(
    DiagnosticCloneStage stage,
    DiagnosticResult result, {
    DiagnosticCloneReason? reason,
    int elapsedMs = 0,
    int statusCode = 0,
    String state = '',
    String issue = '',
    int? sdkCode,
    String sdkSubCode = '',
    int? pollCount,
    String traceId = '',
    bool? requestModelPresent,
    DiagnosticOperation operation = DiagnosticOperation.voiceCloneFlow,
  }) => emitDiagnostic(
    sink,
    DiagnosticEvent(
      operation: operation,
      result: result,
      sessionId: sessionId,
      traceId: traceId,
      elapsedMs: elapsedMs,
      statusCode: statusCode,
      cloneFlow: DiagnosticCloneFlowDetails(
        stage: stage,
        requestModelPresent: requestModelPresent,
        platform: platform,
        reason: reason,
        state: state,
        issue: issue,
        sdkCode: sdkCode,
        sdkSubCode: sdkSubCode,
        pollCount: pollCount,
      ),
    ),
  );

  static DiagnosticCloneReason reason(Object error) {
    if (error is TimeoutException ||
        error is DioException &&
            const {
              DioExceptionType.connectionTimeout,
              DioExceptionType.receiveTimeout,
              DioExceptionType.sendTimeout,
            }.contains(error.type)) {
      return DiagnosticCloneReason.timeout;
    }
    if (error is MissingPluginException) {
      return DiagnosticCloneReason.missingPlugin;
    }
    if (error is PlatformException) {
      return switch (error.code) {
        'capture_unavailable' => switch (error.message) {
          'Camera and microphone permission required' =>
            DiagnosticCloneReason.permissionDenied,
          'Identity audio preparation failed' =>
            DiagnosticCloneReason.audioPreparation,
          'Identity preparation failed' => DiagnosticCloneReason.sdkPreparation,
          'Identity capture failed' => DiagnosticCloneReason.sdkCapture,
          _ => DiagnosticCloneReason.platform,
        },
        'capture_busy' => DiagnosticCloneReason.busy,
        'capture_cancelled' => DiagnosticCloneReason.cancelled,
        'capture_release_failed' => DiagnosticCloneReason.releaseFailed,
        _ => DiagnosticCloneReason.platform,
      };
    }
    if (error is FormatException) return DiagnosticCloneReason.invalidResponse;
    if (error is ArgumentError) return DiagnosticCloneReason.invalidArgument;
    if (error is DioException) {
      return error.type == DioExceptionType.cancel
          ? DiagnosticCloneReason.cancelled
          : DiagnosticCloneReason.network;
    }
    if (error is ApiHttpFailure || error is ApiCodeFailure) {
      return DiagnosticCloneReason.rejected;
    }
    if (error is Enum) {
      return switch (error.name) {
        'priceChanged' => DiagnosticCloneReason.priceChanged,
        'modelRequired' => DiagnosticCloneReason.modelRequired,
        'identityLocked' => DiagnosticCloneReason.identityReplacementRequired,
        'submissionPending' => DiagnosticCloneReason.submissionUnresolved,
        'network' => DiagnosticCloneReason.network,
        'invalidResponse' => DiagnosticCloneReason.invalidResponse,
        'signedOut' => DiagnosticCloneReason.signedOut,
        'sessionChanged' => DiagnosticCloneReason.sessionChanged,
        'rejected' => DiagnosticCloneReason.rejected,
        'busy' => DiagnosticCloneReason.busy,
        'cancelled' => DiagnosticCloneReason.cancelled,
        'unavailable' => DiagnosticCloneReason.platform,
        'identityExpired' => DiagnosticCloneReason.identityExpired,
        _ => DiagnosticCloneReason.unknown,
      };
    }
    return DiagnosticCloneReason.unknown;
  }

  static String _id() {
    final random = Random.secure();
    final b = List.generate(16, (_) => random.nextInt(256));
    b[6] = (b[6] & 15) | 64;
    b[8] = (b[8] & 63) | 128;
    final h = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }
}
