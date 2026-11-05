import 'dart:async';
import 'dart:typed_data';
import 'domestic_model_socket.dart';
import 'domestic_translation_model.dart';
import 'sip_lease.dart';

enum DomesticTranslationLeg { local, remote }

/// Owns both model connections. A cancelled connection is never reused.
class DomesticTranslationProcessor {
  DomesticTranslationProcessor({
    required DomesticModelProtocol local,
    required DomesticModelProtocol remote,
    required this.connect,
    required this.isCurrent,
    required this.onEvent,
    this.prepareTimeout = const Duration(seconds: 10),
    this.keepAlive = false,
  }) : _legs = {
         DomesticTranslationLeg.local: _ModelLeg(local),
         DomesticTranslationLeg.remote: _ModelLeg(remote),
       };

  final DomesticModelConnector connect;
  final bool Function() isCurrent;
  final void Function(DomesticTranslationLeg, DomesticModelEvent) onEvent;
  final Duration prepareTimeout;
  final bool keepAlive;
  final Map<DomesticTranslationLeg, _ModelLeg> _legs;
  final _cancelled = Completer<void>();
  Future<void>? _startWork, _closeWork;
  bool _closed = false, _ready = false;
  bool cleanupUnconfirmed = false;
  String? _failure;
  Timer? _heartbeat;

  bool get ready => _ready && !_closed && isCurrent();

  Future<void> start() => _startWork ??= _start();

  Future<void> _start() async {
    try {
      await Future.wait(
        _legs.entries.map((entry) => _prepare(entry.key, entry.value)),
      );
      if (_closed || !isCurrent()) {
        throw const SipLeaseFailure('MODEL_CANCELLED');
      }
      _ready = true;
      if (keepAlive) {
        _heartbeat = Timer.periodic(const Duration(milliseconds: 5), (_) {
          for (final entry in _legs.entries) {
            if (DateTime.now()
                    .difference(entry.value.lastAudio)
                    .inMilliseconds >=
                20) {
              sendAudio(entry.key, Uint8List(640));
            }
          }
        });
      }
    } catch (_) {
      await close();
      throw SipLeaseFailure(_failure ?? 'MODEL_CANCELLED');
    }
  }

  Future<void> _prepare(DomesticTranslationLeg direction, _ModelLeg leg) async {
    if (_closed || !isCurrent()) {
      throw const SipLeaseFailure('MODEL_CANCELLED');
    }
    // Attach ownership before racing cancellation: even late sockets are closed.
    final pending = connect(leg.protocol.uri, leg.protocol.headers).then((
      socket,
    ) async {
      if (_closed || !isCurrent()) {
        await _closeSocket(socket);
        return null;
      }
      leg.socket = socket;
      return socket;
    });
    try {
      final socket = await Future.any<DomesticModelSocket?>([
        pending,
        _cancelled.future.then((_) => null),
      ]).timeout(prepareTimeout);
      if (socket == null || _closed) {
        throw const SipLeaseFailure('MODEL_CANCELLED');
      }
      leg.subscription = socket.messages.listen(
        (message) => _receive(direction, leg, message),
        onError: (Object _) => _fail('MODEL_CONNECTION_LOST'),
        onDone: () => _fail('MODEL_CONNECTION_LOST'),
      );
      socket.send(leg.protocol.start());
      final confirmed = await leg.confirmed.future.timeout(prepareTimeout);
      if (!confirmed || _closed || !isCurrent()) {
        throw const SipLeaseFailure('MODEL_CANCELLED');
      }
    } on TimeoutException {
      _fail('MODEL_PREPARE_TIMEOUT');
      rethrow;
    } catch (_) {
      if (!_closed) {
        _fail('MODEL_CONNECTION_FAILED');
      }
      rethrow;
    }
  }

  void _receive(
    DomesticTranslationLeg direction,
    _ModelLeg leg,
    Object message,
  ) {
    if (!isCurrent()) {
      if (!_closed) _fail('MODEL_CANCELLED');
      return;
    }
    try {
      for (final event in leg.protocol.decode(message)) {
        if (_closed) {
          if (event is DomesticModelTranscript) onEvent(direction, event);
          continue;
        }
        if (event is DomesticModelReady) {
          if (!leg.confirmed.isCompleted) {
            leg.confirmed.complete(true);
            leg.ready = true;
          }
        } else if (event is DomesticModelError || event is DomesticModelEnded) {
          _fail(
            event is DomesticModelError ? event.code : 'MODEL_CONNECTION_LOST',
          );
          return;
        }
        onEvent(direction, event);
      }
    } catch (_) {
      _fail('MODEL_PROTOCOL_ERROR');
    }
  }

  void sendAudio(DomesticTranslationLeg direction, Uint8List pcm16k) {
    if (!ready) {
      return;
    }
    final leg = _legs[direction]!;
    try {
      leg.socket!.send(leg.protocol.audio(pcm16k));
      leg.lastAudio = DateTime.now();
    } catch (_) {
      _fail('MODEL_AUDIO_SEND_FAILED');
    }
  }

  void _fail(String code) {
    if (_closed) {
      return;
    }
    _failure = code;
    // Publish once, without response bodies or authentication values.
    try {
      onEvent(DomesticTranslationLeg.local, DomesticModelError(code));
    } catch (_) {
      // A presentation callback cannot prevent resource disposal.
    } finally {
      unawaited(close());
    }
  }

  Future<void> close() {
    if (_closeWork != null) {
      return _closeWork!;
    }
    _closed = true;
    _ready = false;
    _heartbeat?.cancel();
    _cancelled.complete();
    for (final leg in _legs.values) {
      if (!leg.confirmed.isCompleted) {
        leg.confirmed.complete(false);
      }
    }
    return _closeWork = _close();
  }

  Future<void> _close() async {
    await Future.wait(
      _legs.values.map((leg) async {
        final socket = leg.socket;
        leg.socket = null;
        if (socket != null) {
          try {
            if (leg.ready) {
              socket.send(leg.protocol.finish());
            }
          } catch (_) {
            /* Best effort. */
          }
          await _closeSocket(socket);
        }
        try {
          await leg.subscription?.cancel();
        } catch (_) {
          cleanupUnconfirmed = true;
        }
      }),
    );
  }

  Future<void> _closeSocket(DomesticModelSocket socket) async {
    try {
      await socket.close();
    } catch (_) {
      cleanupUnconfirmed = true;
    }
  }
}

class _ModelLeg {
  _ModelLeg(this.protocol);
  final DomesticModelProtocol protocol;
  final confirmed = Completer<bool>();
  bool ready = false;
  DomesticModelSocket? socket;
  StreamSubscription<Object>? subscription;
  DateTime lastAudio = DateTime.fromMillisecondsSinceEpoch(0);
}
