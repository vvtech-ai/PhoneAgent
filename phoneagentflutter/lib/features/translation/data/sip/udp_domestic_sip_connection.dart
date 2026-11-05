import 'dart:io';
import '../../domain/sip/domestic_sip_connection.dart';
import '../../domain/sip/domestic_translation_model.dart';
import '../../domain/sip/sip_lease.dart';
import '../../domain/sip/sip_request_builder.dart';
import '../../domain/sip/sip_rtp_transport.dart';
import '../../domain/sip/sip_sdp.dart';
import '../../domain/sip/sip_transactions.dart';
import '../../domain/sip/translation_call_plan.dart';
import 'paced_sip_rtp_transport.dart';
import 'udp_sip_wire.dart';
import 'md5_sip_authenticator.dart';

class UdpDomesticSipConnection implements DomesticSipConnection {
  UdpDomesticSipConnection._(this.wire, this.transactions);
  final UdpSipWire wire;
  final SipTransactions transactions;
  SipRtpTransport? _media;
  SipAudioEndpoint? _endpoint, _negotiated;
  bool _closed = false;
  Future<void>? _closeWork;

  static Future<UdpDomesticSipConnection> open({
    required SipLease lease,
    required TranslationCallPlan plan,
    required String localAddress,
    String? peerAddress,
    required String callId,
    required void Function(SipCallPhase) onPhase,
  }) async {
    if (plan.transport == TranslationCallTransport.overseas ||
        !validSipResourceId(callId) ||
        (lease.expiresAt != null &&
            !lease.expiresAt!.isAfter(DateTime.now()))) {
      throw const SipLeaseFailure('SIP_LEASE_UNAVAILABLE');
    }
    final wire = await UdpSipWire.open(
      lease,
      localAddress: localAddress,
      peerAddress: peerAddress,
    );
    try {
      final builder = SipRequestBuilder(
        lease: lease,
        target: plan.networkNumber,
        localIp: wire.localIp,
        localSipPort: wire.localSipPort,
        localRtpPort: wire.localRtpPort,
        callId: '$callId@phoneagent',
        fromTag: newDomesticModelToken(),
      );
      return UdpDomesticSipConnection._(
        wire,
        SipTransactions(
          builder: builder,
          wire: wire,
          onPhase: onPhase,
          authenticator: const Md5SipAuthenticator(),
        ),
      );
    } catch (_) {
      await wire.close();
      rethrow;
    }
  }

  @override
  Future<SipAudioEndpoint> start() async {
    if (_closed) {
      throw const SipLeaseFailure('SIP_WIRE_CLOSED');
    }
    final endpoint = await transactions.start();
    if (_closed) {
      throw const SipLeaseFailure('SIP_WIRE_CLOSED');
    }
    _negotiated = endpoint;
    final media = await PacedSipRtpTransport.open(
      socket: wire.mediaSocket,
      peer: InternetAddress(endpoint.address),
      peerPort: endpoint.port,
      payloadType: endpoint.payloadType,
      silenceByte: endpoint.codec == SipAudioCodec.pcma ? 0xd5 : 0xff,
    );
    if (_closed) {
      await media.close();
      throw const SipLeaseFailure('SIP_WIRE_CLOSED');
    }
    _media = media;
    return endpoint;
  }

  @override
  Future<void> holdUntilEnded() => transactions.holdUntilEnded();
  @override
  Future<void> sendInfo(String digit) => transactions.sendDtmf(digit);
  @override
  SipRtpTransport media(SipAudioEndpoint endpoint) {
    if (_closed) {
      throw const SipLeaseFailure('SIP_WIRE_CLOSED');
    }
    final negotiated = _negotiated;
    if (negotiated == null ||
        negotiated.address != endpoint.address ||
        negotiated.port != endpoint.port ||
        negotiated.payloadType != endpoint.payloadType ||
        negotiated.codec != endpoint.codec ||
        negotiated.telephoneEventPayload != endpoint.telephoneEventPayload) {
      throw const SipLeaseFailure('RTP_NOT_NEGOTIATED');
    }
    final previous = _endpoint;
    if (previous != null &&
        (previous.address != endpoint.address ||
            previous.port != endpoint.port ||
            previous.payloadType != endpoint.payloadType)) {
      throw const SipLeaseFailure('RTP_ENDPOINT_CHANGED');
    }
    _endpoint = endpoint;
    return _media ?? (throw const SipLeaseFailure('RTP_NOT_NEGOTIATED'));
  }

  @override
  Future<void> close() {
    _closed = true;
    return _closeWork ??= _close();
  }

  Future<void> _close() async {
    try {
      await _media?.close();
    } finally {
      await transactions.close();
    }
  }
}
