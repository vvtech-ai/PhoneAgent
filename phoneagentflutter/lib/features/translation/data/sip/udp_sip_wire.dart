import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import '../../domain/sip/sip_lease.dart';
import '../../domain/sip/sip_message.dart';
import '../../domain/sip/sip_wire.dart';

/// Mobile UDP ports bound to an explicitly resolved local route, never guessed.
class UdpSipWire implements SipWire {
  UdpSipWire._(this._signaling, this.mediaSocket, this._peer, this._peerPort)
    : _rtpPort = mediaSocket.port {
    _subscription = _signaling.listen(
      _read,
      onError: (Object _) => _fail(),
      onDone: _fail,
    );
  }
  final RawDatagramSocket _signaling;
  final RawDatagramSocket mediaSocket;
  final int _rtpPort;
  final InternetAddress _peer;
  final int _peerPort;
  final _queue = Queue<SipMessage>();
  late final StreamSubscription<RawSocketEvent> _subscription;
  Completer<void>? _wake;
  bool _closed = false, _failed = false, _receiving = false;
  Future<void>? _closeWork;
  String get localIp => _signaling.address.address;
  int get localSipPort => _signaling.port;
  int get localRtpPort => _rtpPort;

  static Future<UdpSipWire> open(
    SipLease lease, {
    required String localAddress,
    String? peerAddress,
  }) async {
    RawDatagramSocket? signal, media;
    try {
      if (lease.transport != 'UDP' || lease.port < 1 || lease.port > 65535) {
        throw const SipLeaseFailure('UNSUPPORTED_TRANSPORT');
      }
      final local = InternetAddress(localAddress);
      if (local.isMulticast ||
          local.address == '0.0.0.0' ||
          local.address == '::') {
        throw const SipLeaseFailure('INVALID_LOCAL_ROUTE');
      }
      final peers = peerAddress == null
          ? await InternetAddress.lookup(lease.server, type: local.type)
          : [InternetAddress(peerAddress)];
      if (peers.isEmpty ||
          peers.first.isMulticast ||
          peers.first.type != local.type ||
          const {'0.0.0.0', '::'}.contains(peers.first.address)) {
        throw const SipLeaseFailure('SIP_NETWORK_UNAVAILABLE');
      }
      signal = await RawDatagramSocket.bind(local, 0);
      signal.writeEventsEnabled = false;
      media = await RawDatagramSocket.bind(local, 0);
      media.writeEventsEnabled = false;
      return UdpSipWire._(signal, media, peers.first, lease.port);
    } catch (_) {
      signal?.close();
      media?.close();
      throw const SipLeaseFailure('SIP_NETWORK_UNAVAILABLE');
    }
  }

  void _read(RawSocketEvent event) {
    if (_closed || event != RawSocketEvent.read) return;
    Datagram? packet;
    while ((packet = _signaling.receive()) != null) {
      final value = packet!;
      if (value.address != _peer ||
          value.port != _peerPort ||
          _queue.length >= 64) {
        continue;
      }
      try {
        _queue.add(SipMessage.parse(utf8.decode(value.data)));
        _notify();
      } on FormatException {
        /* A malformed UDP datagram is not a SIP response. */
      } on SipLeaseFailure {
        /* Ignore invalid/unmatched signaling without replay. */
      }
    }
  }

  void _notify() {
    if (_wake != null && !_wake!.isCompleted) _wake!.complete();
  }

  void _fail() {
    if (!_closed) {
      _failed = true;
      _notify();
    }
  }

  @override
  Future<void> send(String packet) async {
    if (_closed || _failed) throw const SipLeaseFailure('SIP_WIRE_CLOSED');
    final bytes = utf8.encode(packet);
    try {
      if (bytes.length > 65507 ||
          _signaling.send(bytes, _peer, _peerPort) != bytes.length) {
        throw const SipLeaseFailure('SIP_SEND_FAILED');
      }
    } catch (_) {
      throw const SipLeaseFailure('SIP_SEND_FAILED');
    }
  }

  @override
  Future<SipMessage?> receive(Duration timeout) async {
    if (_receiving) throw const SipLeaseFailure('SIP_RECEIVE_BUSY');
    _receiving = true;
    try {
      if (_queue.isEmpty && !_closed && !_failed) {
        _wake = Completer<void>();
        await _wake!.future.timeout(timeout, onTimeout: () {});
      }
      if (_failed) throw const SipLeaseFailure('SIP_NETWORK_UNAVAILABLE');
      return _queue.isEmpty ? null : _queue.removeFirst();
    } finally {
      _wake = null;
      _receiving = false;
    }
  }

  @override
  Future<void> close() => _closeWork ??= _close();
  Future<void> _close() async {
    _closed = true;
    _queue.clear();
    _notify();
    _signaling.close();
    mediaSocket.close();
    await _subscription.cancel();
  }
}
