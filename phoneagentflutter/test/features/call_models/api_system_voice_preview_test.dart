import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/call_models/data/api_system_voice_preview.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_preview_player.dart';
import '../../support/synthetic_account_api.dart';

void main() {
  for (final configured in [true, false]) {
    test(
      'preview configured=$configured uses isolated signed URL download',
      () async {
        final api = SyntheticAccountApi();
        final objects = _Objects();
        var generated = 0;
        api.beforeResponse = (request) async {
          if (request.path.contains('/system-voice-preview/')) {
            generated++;
            expect(request.method, 'POST');
            api.data = {
              'url': 'https://media.invalid/sample.wav?signature=synthetic',
            };
          } else {
            api.data = {
              'voices': [
                {
                  'voice': 'new_server_voice',
                  'displayName': '新音色',
                  'defaultVoice': true,
                  'previewAudioUrl': configured
                      ? 'https://media.invalid/sample.wav?signature=synthetic'
                      : '',
                },
              ],
            };
          }
        };
        final port = ApiSystemVoicePreview(
          api.api,
          'QWEN_OMNI_PLUS',
          _Player(),
          client: Dio()..httpClientAdapter = objects,
        );
        addTearDown(api.api.close);
        addTearDown(port.close);
        final bytes = await port.load('new_server_voice');
        expect(bytes, [1, 2, 3]);
        expect(generated, configured ? 0 : 1);
        expect(objects.calls, 1);
        expect(api.requests.first.headers['Authorization'], 'Bearer synthetic');
      },
    );
  }
  test('invalid media address is rejected before object request', () async {
    final api = SyntheticAccountApi()
      ..data = {
        'voices': [
          {'voice': 'v', 'previewAudioUrl': 'http://media.invalid/sample.wav'},
        ],
      };
    final objects = _Objects();
    final port = ApiSystemVoicePreview(
      api.api,
      'QWEN_OMNI_PLUS',
      _Player(),
      client: Dio()..httpClientAdapter = objects,
    );
    addTearDown(api.api.close);
    addTearDown(port.close);
    await expectLater(port.load('v'), throwsA(anything));
    expect(objects.calls, 0);
  });
}

class _Objects implements HttpClientAdapter {
  int calls = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions r,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    calls++;
    expect(r.headers.containsKey('Authorization'), false);
    expect(r.headers.containsKey('X-Account-Id'), false);
    expect(r.headers.containsKey('X-Sign'), false);
    expect(r.followRedirects, false);
    return ResponseBody.fromBytes([1, 2, 3], 200);
  }

  @override
  void close({bool force = false}) {}
}

class _Player implements ClonePreviewPlayer {
  @override
  Future<void> play(Uint8List bytes) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> close() async {}
}
