import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../domain/trusted_caller.dart';
import '../domain/trusted_incoming_identity.dart';
import 'trusted_incoming_identity_dto.dart';
import 'trusted_incoming_diagnostics.dart';
import '../../../core/diagnostics/diagnostic_event.dart';

class DeviceTrustedIncomingIdentityPort implements TrustedIncomingIdentityPort {
  const DeviceTrustedIncomingIdentityPort({
    this.platform,
    this.web,
    this.events,
    this.diagnostics,
    this.retryDelay = const Duration(milliseconds: 250),
  });
  final DiagnosticSink Function()? diagnostics;
  final Duration retryDelay;
  final TargetPlatform? platform;
  final bool? web;
  final Stream<Object?>? events;
  static const _channel = EventChannel('phone_agent/trusted_caller_incoming');
  static const _availability = MethodChannel('phone_agent/trusted_caller');
  static Stream<Object?>? _deviceEvents;

  @override
  Stream<TrustedIncomingIdentity?> watch(
    TrustedCallerOwner owner,
    String environment,
  ) {
    if ((web ?? kIsWeb) ||
        (platform ?? defaultTargetPlatform) != TargetPlatform.iOS ||
        !owner.valid ||
        !{'test', 'pro'}.contains(environment)) {
      return const Stream.empty();
    }
    var active = true;
    var retries = 0;
    Timer? retry;
    final trace = TrustedIncomingDiagnostics(diagnostics?.call(), environment);
    void log(String code, DiagnosticResult result) =>
        trace.record(DiagnosticTrustedCallerStage.incomingStream, code, result);
    StreamSubscription<Object?>? subscription;
    late StreamController<TrustedIncomingIdentity?> controller;
    void finish({required bool clear}) {
      if (!active) return;
      if (clear) controller.add(null);
      active = false;
      retry?.cancel();
      unawaited(subscription?.cancel());
      unawaited(controller.close());
    }

    late Future<void> Function() start;
    Future<void> recover() async {
      if (!active || retry != null) return;
      log('IOS_STREAM_FAILED', DiagnosticResult.failed);
      controller.add(null);
      final previous = subscription;
      subscription = null;
      if (retries >= 2) {
        log('IOS_STREAM_EXHAUSTED', DiagnosticResult.failed);
        finish(clear: false);
        await previous?.cancel();
        return;
      }
      retries++;
      retry = Timer(retryDelay * retries, () {
        retry = null;
        if (active) unawaited(start());
      });
      try {
        await previous?.cancel();
      } catch (_) {}
    }

    start = () async {
      try {
        if (events == null) {
          final available = await _availability.invokeMethod<bool>(
            'incomingEventsAvailable',
            {'environment': environment},
          );
          if (!active) return;
          if (available != true) {
            finish(clear: true);
            return;
          }
        }
        if (!active) return;
        final source =
            events ?? (_deviceEvents ??= _channel.receiveBroadcastStream());
        log('IOS_STREAM_STARTED', DiagnosticResult.started);
        if (retries > 0) log('IOS_STREAM_RETRY', DiagnosticResult.started);
        subscription = source.listen(
          (event) {
            if (!active) return;
            if (trace.consume(event)) return;
            final identity = TrustedIncomingIdentityDto.decode(
              event,
              owner: owner,
              environment: environment,
            );
            if (event != null && identity == null) {
              trace.record(
                DiagnosticTrustedCallerStage.incomingDelivery,
                'IOS_DTO_REJECTED',
                DiagnosticResult.failed,
              );
            }
            controller.add(identity);
          },
          onError: (_) => unawaited(recover()),
          onDone: () => unawaited(recover()),
        );
        if (controller.isPaused) subscription!.pause();
      } on MissingPluginException {
        finish(clear: true);
      } catch (_) {
        // Native payload and error details never escape this data adapter.
        await recover();
      }
    };

    controller = StreamController<TrustedIncomingIdentity?>(
      onListen: () => unawaited(start()),
      onPause: () => subscription?.pause(),
      onResume: () => subscription?.resume(),
      onCancel: () {
        active = false;
        retry?.cancel();
        return subscription?.cancel();
      },
    );
    return controller.stream;
  }
}
