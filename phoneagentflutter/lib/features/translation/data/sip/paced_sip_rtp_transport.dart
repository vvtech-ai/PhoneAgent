import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import '../../domain/sip/sip_pcm_uplink.dart';
import '../../domain/sip/sip_lease.dart';
import '../../domain/sip/sip_rtp_packet.dart';
import '../../domain/sip/sip_rtp_transport.dart';
import 'paced_rtp_worker.dart';

/// Handoff is explicit: same local address and port as the accepted SDP.
class PacedSipRtpTransport
    implements
        SipRtpTransport,
        SipRtpStatistics,
        SipPcmUplink,
        SipPromptUplink {
  PacedSipRtpTransport._();
  final _messages = ReceivePort();
  final _exits = ReceivePort();
  final _packets = StreamController<SipRtpPacket>();
  final _statistics = StreamController<Map<String, int>>.broadcast();
  final _ready = Completer<void>(), _stopped = Completer<void>();
  Isolate? _worker;
  SendPort? _commands;
  Timer? _heartbeat;
  Completer<void>? _prompt;

  void _failPrompt() {
    final prompt = _prompt;
    if (prompt != null && !prompt.isCompleted) {
      prompt.completeError(const SipLeaseFailure('RTP_CLOSED'));
    }
  }

  bool _closed = false;
  static Future<PacedSipRtpTransport> open({
    required RawDatagramSocket socket,
    required InternetAddress peer,
    required int peerPort,
    required int payloadType,
    required int silenceByte,
  }) async {
    if (peerPort < 1 ||
        peerPort > 65535 ||
        peer.isMulticast ||
        const {'0.0.0.0', '::'}.contains(peer.address) ||
        peer.type != socket.address.type) {
      throw const SipLeaseFailure('INVALID_RTP_PEER');
    }
    final address = socket.address.address, port = socket.port;
    final transport = PacedSipRtpTransport._();
    transport._messages.listen(transport._receive);
    transport._exits.listen((_) {
      transport._failPrompt();
      if (!transport._ready.isCompleted) {
        transport._ready.completeError(
          const SipLeaseFailure('RTP_CONNECTION_LOST'),
        );
      } else if (!transport._closed && !transport._stopped.isCompleted) {
        transport._packets.addError(
          const SipLeaseFailure('RTP_CONNECTION_LOST'),
        );
      }
      if (!transport._stopped.isCompleted) transport._stopped.complete();
    });
    socket.close();
    try {
      transport._worker = await Isolate.spawn(pacedRtpWorker, [
        transport._messages.sendPort,
        address,
        port,
        peer.address,
        peerPort,
        payloadType,
        silenceByte,
      ], onExit: transport._exits.sendPort);
      await transport._ready.future.timeout(const Duration(seconds: 3));
      transport._heartbeat = Timer.periodic(const Duration(milliseconds: 500), (
        _,
      ) {
        if (!transport._closed) transport._commands?.send(['alive']);
      });
      return transport;
    } catch (_) {
      await transport.close();
      rethrow;
    }
  }

  void _receive(dynamic message) {
    if (message is! List) return;
    switch (message[0]) {
      case 'ready':
        _commands = message[1] as SendPort;
        if (_closed) _commands!.send(['close']);
        if (!_ready.isCompleted) _ready.complete();
      case 'packet':
        final packet = SipRtpPacket.parse(message[1]);
        if (!_closed && packet != null) _packets.add(packet);
      case 'stats':
        _statistics.add(Map<String, int>.from(message[1] as Map));
      case 'promptDone':
        final prompt = _prompt;
        if (prompt != null && !prompt.isCompleted) prompt.complete();
      case 'error':
        _failPrompt();
        final failure = SipLeaseFailure(message[1] as String);
        if (!_ready.isCompleted) {
          _ready.completeError(failure);
        } else if (!_closed) {
          _packets.addError(failure);
        }
      case 'closed':
        _failPrompt();
        if (!_stopped.isCompleted) _stopped.complete();
    }
  }

  @override
  Stream<SipRtpPacket> get packets => _packets.stream;
  @override
  Stream<Map<String, int>> get statistics => _statistics.stream;
  @override
  void send(SipRtpPacket packet) {
    if (_closed || _commands == null || _stopped.isCompleted) {
      throw const SipLeaseFailure('RTP_CLOSED');
    }
    _commands!.send(['send', packet.encode()]);
  }

  void _command(List<Object> command) {
    if (_closed || _commands == null || _stopped.isCompleted) {
      throw const SipLeaseFailure('RTP_CLOSED');
    }
    _commands!.send(command);
  }

  @override
  void configureUplink(Map<String, num> configuration) =>
      _command(['configure', configuration]);
  @override
  void enqueuePcm(Uint8List pcm, {bool original = false}) =>
      _command(['pcm', Uint8List.fromList(pcm), original]);
  @override
  void finishPcm() => _command(['done']);
  @override
  void sendTelephoneEvents(List<SipRtpPacket> packets) =>
      _command(['events', packets.map((p) => p.encode()).toList()]);

  @override
  Future<void> playPrompt(Uint8List pcm16k) async {
    if (_prompt != null) throw const SipLeaseFailure('RTP_QUEUE_OVERFLOW');
    final prompt = _prompt = Completer<void>();
    try {
      _command(['prompt', Uint8List.fromList(pcm16k)]);
      await prompt.future;
    } finally {
      if (identical(_prompt, prompt)) _prompt = null;
    }
  }

  Future<void>? _closing;
  @override
  Future<void> close() => _closing ??= _close();
  Future<void> _close() async {
    _closed = true;
    _failPrompt();
    _heartbeat?.cancel();
    _commands?.send(['close']);
    try {
      await _stopped.future.timeout(const Duration(seconds: 3));
    } on TimeoutException {
      _worker?.kill(priority: Isolate.immediate);
    }
    _messages.close();
    _exits.close();
    unawaited(_packets.close());
    unawaited(_statistics.close());
  }
}
