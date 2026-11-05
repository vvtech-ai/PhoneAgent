import 'dart:async';
import 'dart:typed_data';
import '../../../../core/diagnostics/diagnostic_event.dart';
import '../../../../core/diagnostics/media_diagnostics.dart';
import 'voice_socket.dart';

/// Single connection lifecycle. Errors deliberately never retain URLs or data.
class VoiceWire {
  VoiceWire(
    this.connector, {
    required this.onMessage,
    required this.onFailure,
    required this.onClosed,
    this.maxFrameBytes = 1024 * 1024,
    this.diagnostics,
  });
  final VoiceSocketConnector connector;
  final void Function(Object) onMessage;
  final void Function(String) onFailure;
  final void Function() onClosed;
  final int maxFrameBytes;
  final MediaDiagnostics? diagnostics;
  VoiceSocket? _socket;
  StreamSubscription<Object>? _subscription;
  bool _closed = false, _opened = false;
  bool _sentPcm = false;
  bool get connected => !_closed && _socket != null;

  Future<void> open(Uri uri) async {
    if (_closed || _opened) return;
    _opened = true;
    diagnostics?.record(DiagnosticMediaStage.connect, DiagnosticResult.started);
    try {
      final socket = await connector(uri);
      if (_closed) {
        diagnostics?.record(
          DiagnosticMediaStage.connect,
          DiagnosticResult.cancelled,
        );
        final closed = await _ignoreFailure(socket.close);
        diagnostics?.record(
          DiagnosticMediaStage.close,
          closed ? DiagnosticResult.succeeded : DiagnosticResult.failed,
        );
        return;
      }
      _socket = socket;
      diagnostics?.record(
        DiagnosticMediaStage.connect,
        DiagnosticResult.succeeded,
      );
      _subscription = socket.messages.listen(
        (message) {
          if (_closed) return;
          if ((message is String && message.length <= maxFrameBytes) ||
              (message is List<int> && message.length <= maxFrameBytes)) {
            try {
              onMessage(
                message is List<int> ? Uint8List.fromList(message) : message,
              );
            } catch (_) {
              if (!_closed) onFailure('invalid_frame');
            }
          } else {
            onFailure('invalid_frame');
          }
        },
        onError: (Object _) {
          if (!_closed) onFailure('transport_error');
        },
        onDone: () {
          if (!_closed) onClosed();
        },
      );
    } catch (_) {
      diagnostics?.record(
        DiagnosticMediaStage.connect,
        _closed ? DiagnosticResult.cancelled : DiagnosticResult.failed,
        reason: _closed ? null : DiagnosticMediaReason.connectFailed,
      );
      if (!_closed) onFailure('connect_failed');
    }
  }

  bool send(Object message) {
    if (!connected) return false;
    try {
      _socket!.send(message);
      if (message is Uint8List && message.isNotEmpty && !_sentPcm) {
        _sentPcm = true;
        diagnostics?.record(
          DiagnosticMediaStage.send,
          DiagnosticResult.succeeded,
        );
      }
      return true;
    } catch (_) {
      onFailure('send_failed');
      return false;
    }
  }

  Future<void> close([String? control]) async {
    if (_closed) return;
    _closed = true;
    final socket = _socket;
    _socket = null;
    if (socket != null && control != null) {
      try {
        socket.send(control);
      } catch (_) {
        /* Best effort final control. */
      }
    }
    // Begin socket shutdown even if stream cleanup is still pending.
    final closed = await Future.wait([
      if (_subscription != null) _ignoreFailure(_subscription!.cancel),
      if (socket != null) _ignoreFailure(socket.close),
    ]);
    if (socket != null) {
      diagnostics?.record(
        DiagnosticMediaStage.close,
        closed.every((value) => value)
            ? DiagnosticResult.succeeded
            : DiagnosticResult.failed,
      );
    }
  }

  Future<bool> _ignoreFailure(Future<void> Function() action) async {
    try {
      await action();
      return true;
    } catch (_) {
      return false; // Preserve best-effort shutdown, without claiming success.
    }
  }
}
