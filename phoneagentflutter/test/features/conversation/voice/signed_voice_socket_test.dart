import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/core/network/service_routes.dart';
import 'package:phone_agent/core/network/signing/c1_credentials.dart';
import 'package:phone_agent/core/network/signing/c1_transport.dart';
import 'package:phone_agent/core/network/signing/c1_request_signer.dart';
import 'package:phone_agent/features/conversation/data/voice/signed_voice_socket.dart';
import 'package:phone_agent/features/conversation/data/voice/voice_socket.dart';

class _Credentials implements C1CredentialSource {
  @override
  Future<C1Credentials> read(ApiService service) async {
    expect(service, ApiService.agent);
    return const C1Credentials(
      apiKey: 'public-fixture',
      secret: 'public-fixture-secret',
      deviceId: '33333333-3333-4333-8333-333333333333',
      clientContext: 'e30',
    );
  }
}

class _Account implements AccountSession {
  @override
  AccountCredentials? credentials = const AccountCredentials(
    'owner',
    'token',
    1,
  );
  @override
  Future<bool> replaceToken(AccountCredentials expected, String token) async =>
      false;
  @override
  Future<void> rejectSession(AccountCredentials expected) async {}
}

class _Socket implements VoiceSocket {
  bool closed = false;
  @override
  Stream<Object> get messages => const Stream.empty();
  @override
  void send(Object message) {}
  @override
  Future<void> close() async {
    closed = true;
  }
}

void main() {
  test('media correlation query is included in the signed upgrade', () async {
    const id = '11111111-1111-4111-8111-111111111111';
    final endpoint = Uri.parse(
      'wss://example.test/aiassistant-runtime/ws/assistant/task-voice/tts?mediaRequestId=$id',
    );
    final transport = SignedVoiceSocket(
      _Account(),
      C1Transport(
        _Credentials(),
        requestId: () => id,
        now: () => 1700000000000,
      ),
      connect: (uri, headers) async {
        expect(uri, endpoint);
        expect(
          headers['X-Sign'],
          C1RequestSigner.sign(
            method: 'GET',
            uri: endpoint,
            requestId: id,
            timestamp: 1700000000000,
            deviceId: '33333333-3333-4333-8333-333333333333',
            apiKey: 'public-fixture',
            secret: 'public-fixture-secret',
            clientContext: 'e30',
            accessToken: 'token',
            body: const [],
          ),
        );
        return _Socket();
      },
    );
    await transport.open(endpoint);
  });
  test(
    'native upgrade shares C1 and Bearer; late account result is closed without replay',
    () async {
      final account = _Account(),
          socket = _Socket(),
          pending = Completer<VoiceSocket>();
      var connections = 0;
      final transport = SignedVoiceSocket(
        account,
        C1Transport(_Credentials()),
        connect: (uri, headers) {
          connections++;
          expect(uri.path, '/aiassistant-api/ws/assistant/asr');
          expect(headers['Authorization'], 'Bearer token');
          expect(headers['X-Account-Id'], 'owner');
          expect(headers['X-Sign'], matches(RegExp(r'^[0-9a-f]{64}$')));
          return pending.future;
        },
      );
      final result = transport.open(
        Uri.parse('wss://example.test/aiassistant-api/ws/assistant/asr'),
      );
      await Future<void>.delayed(Duration.zero);
      account.credentials = const AccountCredentials('other', 'new-token', 2);
      pending.complete(socket);
      await expectLater(result, throwsA(ApiFailure.sessionChanged));
      expect(socket.closed, isTrue);
      expect(connections, 1);
    },
  );
}
