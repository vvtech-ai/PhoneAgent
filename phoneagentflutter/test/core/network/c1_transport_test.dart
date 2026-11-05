import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/network/service_routes.dart';
import 'package:phone_agent/core/network/signing/c1_credentials.dart';
import 'package:phone_agent/core/network/signing/c1_transport.dart';

class _Credentials implements C1CredentialSource {
  final services = <ApiService>[];
  @override
  Future<C1Credentials> read(ApiService service) async {
    services.add(service);
    return C1Credentials(
      apiKey: 'public-fixture',
      secret: 'public-fixture-secret',
      deviceId: '33333333-3333-4333-8333-333333333333',
      clientContext: base64Url.encode(utf8.encode('{}')).replaceAll('=', ''),
    );
  }
}

void main() {
  test(
    'token refresh signs the same serialized body with a fresh request ID',
    () async {
      final source = _Credentials();
      var id = 0;
      final signer = C1Transport(
        source,
        now: () => 1789084800000,
        requestId: () =>
            '${(++id).toString().padLeft(8, '0')}-1111-4111-8111-111111111111',
      );
      final uri = Uri.parse(
        'https://example.test/aiassistant-api/api/agent/chat/stream',
      );
      final first = await signer.prepare(
        uri,
        service: ApiService.agent,
        method: 'POST',
        token: 'old',
        body: {'text': '确认拨打'},
      );
      final replay = await signer.prepare(
        uri,
        service: ApiService.agent,
        method: 'POST',
        token: 'new',
        body: {'text': '确认拨打'},
      );
      expect(first.$1, '{"text":"确认拨打"}');
      expect(first.$1, replay.$1);
      expect(first.$2['X-Reqid'], isNot(replay.$2['X-Reqid']));
      expect(first.$2['X-Sign'], isNot(replay.$2['X-Sign']));
      expect(source.services, [ApiService.agent, ApiService.agent]);
    },
  );
  test(
    'multipart hashing leaves original streams reusable for the upload',
    () async {
      final signer = C1Transport(_Credentials());
      final form = FormData.fromMap({
        'userId': 'owner',
        'file': MultipartFile.fromBytes([1, 2, 3], filename: 'task.csv'),
      });
      final signed = await signer.prepare(
        Uri.parse('https://example.test/api/documents/parse'),
        service: ApiService.sdk,
        method: 'POST',
        token: '',
        body: form,
      );
      expect(signed.$1, isA<FormData>());
      expect(form.isFinalized, isFalse);
      expect(
        await form.files.single.value
            .clone()
            .finalize()
            .expand((e) => e)
            .toList(),
        [1, 2, 3],
      );
    },
  );
}
