import 'dart:convert';
import 'sip_lease.dart';
import 'sip_message.dart';
import 'sip_sdp.dart';

class SipDialog {
  const SipDialog({
    required this.toHeader,
    required this.inviteCseq,
    required this.requestUri,
    this.routes = const [],
  });
  final String toHeader, requestUri;
  final int inviteCseq;
  final List<String> routes;
}

/// Native UDP SIP wire contract. Credentials are only used by Digest externally.
class SipRequestBuilder {
  SipRequestBuilder({
    required this.lease,
    required this.target,
    required this.localIp,
    required this.localSipPort,
    required this.localRtpPort,
    required this.callId,
    required this.fromTag,
  }) {
    if (!RegExp(r'^[0-9]+$').hasMatch(target) ||
        !RegExp(r'^[A-Za-z0-9_.+%-]+$').hasMatch(lease.username) ||
        !RegExp(r'^[A-Za-z0-9_.+%-]+$').hasMatch(lease.callerNumber) ||
        !validSipResourceId(fromTag) ||
        !RegExp(r'^[A-Za-z0-9_.@-]+$').hasMatch(callId) ||
        localSipPort < 1 ||
        localSipPort > 65535) {
      throw const SipLeaseFailure('INVALID_SIP_REQUEST');
    }
    SipSdp.offer(localIp, localRtpPort);
  }
  final SipLease lease;
  final String target, localIp, callId, fromTag;
  final int localSipPort, localRtpPort;
  String get _server => '${_host(lease.server)}:${lease.port}';
  String get registerUri => 'sip:$_server;transport=udp';
  String get inviteUri => 'sip:$target@$_server;transport=udp;user=phone';
  String _address(String user) => '<sip:$user@$_server>';
  String get _targetAddress => '<sip:$target@$_server;user=phone>';
  String get _contact =>
      'Contact: <sip:${lease.username}@${_host(localIp)}:$localSipPort;transport=udp>';
  String _via(String branch) {
    if (!branch.startsWith('z9hG4bK') || !validSipResourceId(branch)) {
      throw const SipLeaseFailure('INVALID_SIP_BRANCH');
    }
    return 'Via: SIP/2.0/UDP ${_host(localIp)}:$localSipPort;branch=$branch;rport';
  }

  String register({
    required String branch,
    required int cseq,
    String? authorization,
  }) => _packet([
    'REGISTER $registerUri SIP/2.0',
    _via(branch),
    'Max-Forwards: 70',
    'From: ${_address(lease.username)};tag=$fromTag',
    'To: ${_address(lease.username)}',
    'Call-ID: $callId',
    'CSeq: $cseq REGISTER',
    _contact,
    'Expires: 300',
    'User-Agent: PhoneAgent-Flutter',
    if (authorization != null) authorization,
  ]);

  String invite({
    required String branch,
    required int cseq,
    String? authorization,
  }) => _packet([
    'INVITE $inviteUri SIP/2.0',
    _via(branch),
    'Max-Forwards: 70',
    'From: ${_address(lease.callerNumber)};tag=$fromTag',
    'To: $_targetAddress',
    'Call-ID: $callId',
    'CSeq: $cseq INVITE',
    _contact,
    'Allow: INVITE, ACK, CANCEL, BYE, INFO, OPTIONS',
    'Supported: replaces, timer',
    'Content-Type: application/sdp',
    if (authorization != null) authorization,
  ], SipSdp.offer(localIp, localRtpPort));

  String cancel({
    required String branch,
    required int inviteCseq,
    required String toHeader,
  }) => _packet([
    'CANCEL $inviteUri SIP/2.0',
    _via(branch),
    'Max-Forwards: 70',
    'From: ${_address(lease.callerNumber)};tag=$fromTag',
    'To: $toHeader',
    'Call-ID: $callId',
    'CSeq: $inviteCseq CANCEL',
  ]);

  String dialog(
    String method,
    SipDialog dialog, {
    required String branch,
    required int cseq,
    String? digit,
  }) {
    if (!const {'ACK', 'BYE', 'INFO'}.contains(method) ||
        (method == 'INFO' &&
            (digit == null || !RegExp(r'^[0-9*#]$').hasMatch(digit)))) {
      throw const SipLeaseFailure('INVALID_SIP_REQUEST');
    }
    _sipUri(dialog.requestUri);
    for (final route in dialog.routes) {
      _sipUri(route);
    }
    return _packet([
      '$method ${dialog.requestUri} SIP/2.0',
      _via(branch),
      'Max-Forwards: 70',
      'From: ${_address(lease.callerNumber)};tag=$fromTag',
      'To: ${dialog.toHeader}',
      'Call-ID: $callId',
      'CSeq: $cseq $method',
      for (final route in dialog.routes) 'Route: <$route>',
      _contact,
      if (method == 'INFO') 'Content-Type: application/dtmf-relay',
    ], method == 'INFO' ? 'Signal=$digit\r\nDuration=160\r\n' : '');
  }

  SipDialog dialogFrom(
    SipMessage response,
    int inviteCseq, {
    bool success = true,
  }) {
    final contact = response.header('contact');
    final contacts = contact == null ? <String>[] : _uris(contact);
    final routes = success
        ? response
              .headerValues('record-route')
              .expand(_uris)
              .toList()
              .reversed
              .toList()
        : <String>[];
    return SipDialog(
      toHeader: response.header('to') ?? _targetAddress,
      inviteCseq: inviteCseq,
      requestUri: success && contacts.isNotEmpty ? contacts.first : inviteUri,
      routes: List.unmodifiable(routes),
    );
  }

  static String ok(SipMessage request) => _response(request, '200 OK');
  static String rejectDialog(SipMessage request) =>
      _response(request, '481 Call/Transaction Does Not Exist');
  static String _response(SipMessage request, String status) => _packet([
    'SIP/2.0 $status',
    for (final via in request.headerValues('via')) 'Via: $via',
    for (final name in ['From', 'To', 'Call-ID', 'CSeq'])
      if (request.header(name) != null) '$name: ${request.header(name)}',
  ]);

  static String _packet(List<String> headers, [String body = '']) {
    if (headers.any((header) => header.contains(RegExp(r'[\r\n\x00]')))) {
      throw const SipLeaseFailure('INVALID_SIP_REQUEST');
    }
    return [
      ...headers,
      'Content-Length: ${utf8.encode(body).length}',
      '',
      body,
    ].join('\r\n');
  }

  static String _host(String value) {
    if (!RegExp(r'^[A-Za-z0-9.:-]+$').hasMatch(value)) {
      throw const SipLeaseFailure('INVALID_SIP_HOST');
    }
    return value.contains(':') ? '[$value]' : value;
  }

  static void _sipUri(String value) {
    if (!RegExp(r'^sip:[^\s<>"\r\n]+$').hasMatch(value)) {
      throw const SipLeaseFailure('INVALID_SIP_URI');
    }
  }

  static List<String> _uris(String value) {
    final angles = RegExp(
      r'<\s*(sip[s]?:[^>\s]+)\s*>',
      caseSensitive: false,
    ).allMatches(value).map((match) => match.group(1)!).toList();
    final uris = angles.isNotEmpty
        ? angles
        : RegExp(
            r'\bsip[s]?:[^,\s>]+',
            caseSensitive: false,
          ).allMatches(value).map((match) => match.group(0)!).toList();
    for (final uri in uris) {
      _sipUri(uri);
    }
    return uris;
  }
}
