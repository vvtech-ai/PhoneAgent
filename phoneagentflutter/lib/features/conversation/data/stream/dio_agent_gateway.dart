import 'dart:async';
import 'package:dio/dio.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/network/account_session.dart';
import '../../../../core/network/account_api.dart';
import '../../../../core/network/stream_client.dart'
    if (dart.library.js_interop) '../../../../core/network/stream_client_web.dart';
import '../../domain/agent_protocol.dart';
import '../../domain/agent_failure.dart';
import 'agent_event_decoder.dart';
import 'agent_stream_diagnostics.dart';
import 'sse_frame_decoder.dart';
import '../../../../core/diagnostics/diagnostic_event.dart';

class DioAgentGateway implements AgentGateway {
  DioAgentGateway(
    AppConfig config,
    this._session, {
    Dio? client,
    this.diagnostics,
    this.userContextProvider,
    this.beforeContext,
    AccountApi? api,
  }) : _base = config.apiBaseUri,
       _client = client ?? createStreamClient() {
    _owner = _session.credentials;
    _api = api ?? AccountApi(config, _session, client: _client);
    _ownsApi = api == null;
    _client.options = BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: Duration.zero,
      sendTimeout: const Duration(seconds: 90),
      followRedirects: false,
      contentType: Headers.jsonContentType,
      validateStatus: (_) => true,
    );
  }
  final Dio _client;
  final Uri? _base;
  final AccountSession _session;
  final DiagnosticSink? diagnostics;
  final Future<Map<String, Object?>> Function()? userContextProvider;
  final Future<void> Function(AgentCommand command, bool Function() isCurrent)?
  beforeContext;
  late final AccountCredentials? _owner;
  late final AccountApi _api;
  late final bool _ownsApi;
  void close() {
    if (_ownsApi) _api.close();
    _client.close(force: true);
  }

  @override
  AgentRun start(AgentCommand command) {
    final cancellation = CancelToken();
    var cancelled = false;
    late StreamController<AgentEvent> output;
    void cancel() {
      cancelled = true;
      cancellation.cancel();
    }

    void checkOwner() {
      if (_owner == null ||
          !_owner.sameLogin(_session.credentials) ||
          command.userId != _owner.accountId) {
        throw AgentTransportFailure.sessionChanged;
      }
    }

    Future<void> execute() async {
      var terminal = false;
      var failed = false;
      var streamSequence = 0;
      var handshakeStatus = 0;
      final watch = Stopwatch()..start();
      try {
        checkOwner();
        emitDiagnostic(
          diagnostics,
          DiagnosticEvent(
            operation: DiagnosticOperation.agentStream,
            result: DiagnosticResult.started,
            sessionId: command.sessionId,
            traceId: command.traceId,
          ),
        );
        final base = _base;
        if (base == null) throw AgentTransportFailure.unavailable;
        if ([
          command.sessionId,
          command.commandId,
          command.idempotencyKey,
          command.traceId,
        ].any((s) => s.trim().isEmpty)) {
          throw AgentTransportFailure.malformed;
        }
        final payload = command.toJson();
        if (beforeContext != null) {
          await beforeContext!(
            command,
            () =>
                !cancelled &&
                _owner != null &&
                _owner.sameLogin(_session.credentials),
          );
          checkOwner();
          if (cancelled) return;
        }
        if (userContextProvider != null) {
          Map<String, Object?> context = const {};
          try {
            context = await userContextProvider!();
          } catch (_) {}
          checkOwner();
          if (cancelled) return;
          if (context.isNotEmpty) {
            payload['userContext'] = {...?command.userContext, ...context};
          }
        }
        final response = await _api.openAgentStream(payload, cancellation);
        handshakeStatus = 200;
        checkOwner();
        if (cancelled) return;
        final contentType = response.headers['content-type']?.firstOrNull ?? '';
        if (!contentType.toLowerCase().startsWith('text/event-stream')) {
          throw AgentTransportFailure.malformed;
        }
        await for (final frame in const SseFrameDecoder().decode(
          response.stream,
        )) {
          if (cancelled) break;
          checkOwner();
          final event = const AgentEventDecoder().decode(frame);
          if (event.sessionId.isNotEmpty &&
              event.sessionId != command.sessionId) {
            throw AgentTransportFailure.malformed;
          }
          output.add(event);
          traceAgentEvent(
            event,
            sessionId: command.sessionId,
            commandId: command.commandId,
            sequence: ++streamSequence,
          );
          if (event.kind == AgentEventKind.error) failed = true;
          recordAgentEvent(
            event,
            sessionId: command.sessionId,
            traceId: command.traceId,
            sink: diagnostics,
          );
          if ({
            AgentEventKind.signal,
            AgentEventKind.finalResponse,
            AgentEventKind.error,
          }.contains(event.kind)) {
            terminal = true;
          }
          if (event.eventName == 'task_cancelled') terminal = true;
          if (event.kind == AgentEventKind.done) {
            terminal = true;
            break;
          }
        }
        if (!terminal && !cancelled) throw AgentTransportFailure.incomplete;
      } on ApiCodeFailure catch (error) {
        failed = true;
        handshakeStatus = error.statusCode;
        if (!cancelled) {
          output.addError(
            error.statusCode >= 500
                ? AgentTransportFailure.network
                : AgentFailure(errorCode: error.code),
          );
        }
      } on ApiHttpFailure catch (error) {
        failed = true;
        handshakeStatus = error.statusCode;
        if (!cancelled) {
          output.addError(
            error.statusCode >= 500
                ? AgentTransportFailure.network
                : AgentTransportFailure.rejected,
          );
        }
      } on ApiFailure catch (error) {
        failed = true;
        if (!cancelled) {
          output.addError(switch (error) {
            ApiFailure.unavailable => AgentTransportFailure.unavailable,
            ApiFailure.sessionChanged => AgentTransportFailure.sessionChanged,
            ApiFailure.network => AgentTransportFailure.network,
            _ => AgentTransportFailure.rejected,
          });
        }
      } on DioException catch (error) {
        failed = true;
        handshakeStatus = error.response?.statusCode ?? 0;
        if (!cancelled && !CancelToken.isCancel(error)) {
          output.addError(AgentTransportFailure.network);
        }
      } on AgentTransportFailure catch (error) {
        failed = true;
        if (!cancelled) output.addError(error);
      } catch (_) {
        failed = true;
        if (!cancelled) output.addError(AgentTransportFailure.malformed);
      } finally {
        emitDiagnostic(
          diagnostics,
          DiagnosticEvent(
            operation: DiagnosticOperation.agentStream,
            result: cancelled
                ? DiagnosticResult.cancelled
                : failed
                ? DiagnosticResult.failed
                : DiagnosticResult.succeeded,
            elapsedMs: watch.elapsedMilliseconds,
            statusCode: handshakeStatus,
            sessionId: command.sessionId,
            traceId: command.traceId,
          ),
        );
        cancellation.cancel();
        await output.close();
      }
    }

    output = StreamController<AgentEvent>(onListen: execute, onCancel: cancel);
    return AgentRun(output.stream, cancel);
  }
}
