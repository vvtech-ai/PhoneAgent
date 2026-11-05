import 'dart:async';
import 'dart:io';
import '../../domain/sip/sip_lease.dart';
import '../../domain/sip/sip_rtp_packet.dart';
import '../../domain/sip/sip_rtp_transport.dart';

/// Uses the media port already advertised in SDP. It never guesses a peer.
class UdpSipRtpTransport implements SipRtpTransport {
  UdpSipRtpTransport({
    required RawDatagramSocket socket,
    required InternetAddress peer,
    required int peerPort,
  }) : _socket = socket,
       _peer = peer,
       _peerPort = peerPort {
    if (peerPort < 1 ||
        peerPort > 65535 ||
        peer.isMulticast ||
        peer.address == '0.0.0.0' ||
        peer.address == '::' ||
        peer.type != socket.address.type) {
      throw const SipLeaseFailure('INVALID_RTP_PEER');
    }
    _socket.writeEventsEnabled = false;
    _packets = StreamController<SipRtpPacket>(
      sync: true,
      onListen: () {
        if (_closed) {
          return;
        }
        _subscription = _socket.listen(
          _read,
          onError: (Object _) => _fail(),
          onDone: _fail,
        );
      },
      onCancel: close,
    );
  }
  final RawDatagramSocket _socket;
  final InternetAddress _peer;
  final int _peerPort;
  late final StreamController<SipRtpPacket> _packets;
  StreamSubscription<RawSocketEvent>? _subscription;
  bool _closed = false;
  Future<void>? _closeWork;

  @override
  Stream<SipRtpPacket> get packets => _packets.stream;

  void _read(RawSocketEvent event) {
    if (_closed || event != RawSocketEvent.read) {
      return;
    }
    Datagram? datagram;
    // Limit each event batch so media cannot starve cancellation or signaling.
    for (var count = 0; count < 64 && !_closed; count++) {
      datagram = _socket.receive();
      if (datagram == null) {
        break;
      }
      if (datagram.address != _peer || datagram.port != _peerPort) {
        continue;
      }
      final packet = SipRtpPacket.parse(datagram.data);
      if (packet != null && !_packets.isPaused) {
        _packets.add(packet);
      }
    }
  }

  void _fail() {
    if (_closed) {
      return;
    }
    _packets.addError(const SipLeaseFailure('RTP_CONNECTION_LOST'));
    unawaited(close());
  }

  @override
  void send(SipRtpPacket packet) {
    if (_closed) {
      throw const SipLeaseFailure('RTP_CLOSED');
    }
    final bytes = packet.encode();
    try {
      if (_socket.send(bytes, _peer, _peerPort) != bytes.length) {
        throw const SipLeaseFailure('RTP_SEND_FAILED');
      }
    } catch (_) {
      throw const SipLeaseFailure('RTP_SEND_FAILED');
    }
  }

  @override
  Future<void> close() {
    if (_closeWork != null) {
      return _closeWork!;
    }
    _closed = true;
    _socket.close();
    return _closeWork = _close();
  }

  Future<void> _close() async {
    await _subscription?.cancel();
    // Stream cancellation can re-enter close; never await the close callback.
    unawaited(_packets.close());
  }
}
