import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import '../../domain/sip/domestic_model_socket.dart';
import '../../domain/sip/sip_lease.dart';

/// Authenticated upgrade with redirects disabled. Credentials never enter logs.
Future<DomesticModelSocket> connectDomesticModelSocket(
  Uri uri,
  Map<String, String> headers, {
  Duration timeout = const Duration(seconds: 10),
  HttpClient Function()? clientFactory,
}) async {
  const allowed = {
    'authorization',
    'x-dashscope-datainspection',
    'x-api-key',
    'x-api-access-key',
    'x-api-resource-id',
    'x-api-app-key',
    'x-api-connect-id',
  };
  if (uri.scheme != 'wss' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment ||
      headers.isEmpty ||
      headers.entries.any(
        (entry) =>
            !allowed.contains(entry.key.toLowerCase()) ||
            entry.value.isEmpty ||
            entry.value.contains(RegExp(r'[\r\n\x00]')),
      )) {
    throw const SipLeaseFailure('MODEL_CONFIGURATION_UNAVAILABLE');
  }
  final client = (clientFactory ?? HttpClient.new)();
  client.connectionTimeout = timeout;
  var expired = false;
  Socket? detached;
  Future<DomesticModelSocket> upgrade() async {
    final nonce = base64.encode(
      List.generate(16, (_) => Random.secure().nextInt(256)),
    );
    final request = await client.getUrl(uri.replace(scheme: 'https'));
    if (expired) {
      throw const SipLeaseFailure('MODEL_PREPARE_TIMEOUT');
    }
    request.followRedirects = false;
    headers.forEach(request.headers.set);
    request.headers.set(HttpHeaders.connectionHeader, 'Upgrade');
    request.headers.set(HttpHeaders.upgradeHeader, 'websocket');
    request.headers.set('Sec-WebSocket-Version', '13');
    request.headers.set('Sec-WebSocket-Key', nonce);
    final response = await request.close();
    final expected = base64.encode(
      sha1
          .convert(
            utf8.encode(
              '$nonce'
              '258EAFA5-E914-47DA-95CA-C5AB0DC85B11',
            ),
          )
          .bytes,
    );
    final connection = response.headers.value(HttpHeaders.connectionHeader);
    if (expired ||
        response.statusCode != HttpStatus.switchingProtocols ||
        response.headers.value(HttpHeaders.upgradeHeader)?.toLowerCase() !=
            'websocket' ||
        !(connection
                ?.split(',')
                .any((part) => part.trim().toLowerCase() == 'upgrade') ??
            false) ||
        response.headers.value('Sec-WebSocket-Accept') != expected) {
      throw const SipLeaseFailure('MODEL_CONNECTION_FAILED');
    }
    detached = await response.detachSocket();
    if (expired) {
      detached!.destroy();
      throw const SipLeaseFailure('MODEL_PREPARE_TIMEOUT');
    }
    final socket = WebSocket.fromUpgradedSocket(detached!, serverSide: false);
    return _IoDomesticModelSocket(socket, client, detached!);
  }

  try {
    return await upgrade().timeout(timeout);
  } catch (_) {
    expired = true;
    detached?.destroy();
    client.close(force: true);
    throw const SipLeaseFailure('MODEL_CONNECTION_FAILED');
  }
}

class _IoDomesticModelSocket implements DomesticModelSocket {
  _IoDomesticModelSocket(this.socket, this.client, this.transport);
  final WebSocket socket;
  final HttpClient client;
  final Socket transport;
  Future<void>? _closeWork;
  @override
  Stream<Object> get messages => socket.cast<Object>();
  @override
  void send(Object message) => socket.add(message);
  @override
  Future<void> close() => _closeWork ??= _close();
  Future<void> _close() async {
    try {
      await socket
          .close(WebSocketStatus.normalClosure)
          .timeout(const Duration(seconds: 2));
    } finally {
      transport.destroy();
      client.close(force: true);
    }
  }
}
