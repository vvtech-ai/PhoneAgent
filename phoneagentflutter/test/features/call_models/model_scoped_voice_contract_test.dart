import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/call_models/data/api_call_model_repository.dart';
import 'package:phone_agent/features/call_models/data/api_clone_voice_repository.dart';
import '../../support/synthetic_account_api.dart';
import 'package:phone_agent/features/call_models/presentation/controller/call_model_controller.dart';

Map<String, Object?> selection(String mode, [String voice = 'old']) => {
  'selectionMode': mode,
  'activeVoice': voice,
  'voices': [
    {'voice': 'old', 'displayName': '原音色'},
    {'voice': 'new', 'displayName': '新音色'},
  ],
};

class _Reply {
  const _Reply(this.data, {this.status = 200});
  final Object? data;
  final int status;
}

SyntheticAccountApi _script(List<_Reply> replies) {
  final fixture = SyntheticAccountApi();
  addTearDown(fixture.api.close);
  var index = 0;
  fixture.beforeResponse = (_) async {
    expect(
      index,
      lessThan(replies.length),
      reason: 'no automatic write replay',
    );
    final reply = replies[index++];
    fixture.data = reply.data;
    fixture.status = reply.status;
  };
  return fixture;
}

void main() {
  test(
    'current A stays unchanged while B clone is selected and reopened',
    () async {
      final fixture = SyntheticAccountApi();
      addTearDown(fixture.api.close);
      var mode = 'AI';
      var voice = 'old';
      fixture.beforeResponse = (request) async {
        final path = request.uri.path;
        if (path.endsWith('/realtime-call-provider')) {
          expect(request.method, 'GET');
          fixture.data = {
            'activeModelId': '4',
            'providers': [
              for (final id in ['4', '5'])
                {
                  'modelId': id,
                  'provider': 'QWEN_OMNI_PLUS',
                  'cloneModelId': '13',
                  'supportsVoiceClone': true,
                  'available': true,
                  'active': id == '4',
                },
            ],
          };
        } else if (path.endsWith('/voice-clone/models')) {
          fixture.data = {
            'models': [
              {
                'modelId': '5',
                'available': true,
                'current': {
                  'modelId': '5',
                  'status': 'READY',
                  'providerAssetId': 'synthetic',
                },
              },
            ],
          };
        } else if (path.endsWith('/voice-clone/activate') ||
            path.endsWith('/voice-clone/deactivate')) {
          expect(request.uri.queryParameters, {'modelId': '5'});
          mode = path.endsWith('/activate') ? 'CLONE' : 'AI';
          fixture.data = {'modelId': '5', 'active': mode == 'CLONE'};
        } else {
          expect(path, endsWith('/realtime-call-voice/models/5'));
          if (request.method == 'PUT') {
            voice = (request.data as Map)['voice'] as String;
          }
          fixture.data = selection(mode, voice);
        }
      };
      final controller = CallModelController(
        ApiCallModelRepository(fixture.api),
        cloneRepository: ApiCloneVoiceRepository(fixture.api),
      );
      addTearDown(controller.dispose);
      await controller.load();
      await controller.loadVoices('5');
      expect(controller.state.voices!.selectionMode, 'AI');
      await controller.selectClone();
      expect(controller.state.voices!.selectionMode, 'CLONE');
      expect(controller.state.catalog!.activeProvider, '4');
      await controller.loadVoices('5');
      expect(controller.state.voices!.selectionMode, 'CLONE');
      await controller.selectVoice(controller.state.voices!.voices.last);
      expect(controller.state.voices!.activeVoice, 'new');
      expect(controller.state.voices!.selectionMode, 'AI');
      expect(controller.state.catalog!.activeProvider, '4');
    },
  );
  test(
    'numeric target model activates and reloads without global voice PUT',
    () async {
      final fixture = _script([
        const _Reply({'active': true, 'modelId': '4'}),
        _Reply(selection('CLONE')),
      ]);
      final result = await ApiCloneVoiceRepository(
        fixture.api,
      ).selectConfirmed('4');
      expect(result.selectionMode, 'CLONE');
      expect(fixture.requests.map((r) => r.method), ['POST', 'GET']);
      expect(
        fixture.requests.first.uri.path,
        endsWith('/voice-clone/activate'),
      );
      expect(fixture.requests.first.uri.queryParameters, {'modelId': '4'});
      expect(
        fixture.requests.last.uri.path,
        endsWith('/realtime-call-voice/models/4'),
      );
      expect(
        fixture.requests.every(
          (r) => r.headers['Authorization'] == 'Bearer synthetic',
        ),
        true,
      );
    },
  );

  test('activation failure is not replayed or treated as selected', () async {
    final fixture = _script([const _Reply({}, status: 503)]);
    await expectLater(
      ApiCloneVoiceRepository(fixture.api).selectConfirmed('4'),
      throwsA(anything),
    );
    expect(fixture.requests, hasLength(1));
  });

  test('activation accepted but AI reread is not clone success', () async {
    final fixture = _script([
      const _Reply({'active': true}),
      _Reply(selection('AI')),
    ]);
    await expectLater(
      ApiCloneVoiceRepository(fixture.api).selectConfirmed('4'),
      throwsA(ApiFailure.invalidResponse),
    );
    expect(fixture.requests, hasLength(2));
  });

  test(
    'system switch targets B while reading only B, deactivates then updates',
    () async {
      final fixture = _script([
        _Reply(selection('CLONE')),
        const _Reply({'active': false}),
        _Reply(selection('AI')),
        _Reply(selection('AI', 'new')),
      ]);
      final result = await ApiCallModelRepository(
        fixture.api,
      ).selectVoice('5', 'new');
      expect(result.activeVoice, 'new');
      expect(fixture.requests.map((r) => r.method), [
        'GET',
        'POST',
        'GET',
        'PUT',
      ]);
      expect(fixture.requests[1].uri.queryParameters, {'modelId': '5'});
      expect(fixture.requests[1].uri.path, endsWith('/voice-clone/deactivate'));
      for (final request in fixture.requests.where((r) => r.method != 'POST')) {
        expect(request.uri.path, endsWith('/realtime-call-voice/models/5'));
      }
      expect(fixture.requests.last.data, {
        'voice': 'new',
        'selectionMode': 'AI',
      });
    },
  );

  test(
    'lost deactivate reply reconciles inactive status without replay',
    () async {
      final fixture = _script([
        _Reply(selection('CLONE')),
        const _Reply({}, status: 503),
        const _Reply({'active': false}),
        _Reply(selection('AI')),
      ]);
      final result = await ApiCallModelRepository(
        fixture.api,
      ).selectVoice('4', 'old');
      expect(result.selectionMode, 'AI');
      expect(fixture.requests.map((r) => r.method), [
        'GET',
        'POST',
        'GET',
        'GET',
      ]);
      expect(fixture.requests[2].uri.path, endsWith('/voice-clone'));
      expect(fixture.requests[2].uri.queryParameters, {'modelId': '4'});
    },
  );

  test('uncertain deactivate status cannot proceed to system PUT', () async {
    for (final status in [true, null]) {
      final fixture = _script([
        _Reply(selection('CLONE')),
        const _Reply({}, status: 503),
        _Reply({'active': status}),
      ]);
      await expectLater(
        ApiCallModelRepository(fixture.api).selectVoice('4', 'new'),
        throwsA(anything),
      );
      expect(fixture.requests.map((r) => r.method), ['GET', 'POST', 'GET']);
    }
  });

  test('read failure after deactivate never attempts voice update', () async {
    final fixture = _script([
      _Reply(selection('CLONE')),
      const _Reply({'active': false}),
      const _Reply({}, status: 503),
    ]);
    await expectLater(
      ApiCallModelRepository(fixture.api).selectVoice('4', 'new'),
      throwsA(anything),
    );
    expect(fixture.requests, hasLength(3));
  });

  test(
    'lost system update reply succeeds only if reread matches target',
    () async {
      for (final latest in ['old', 'new']) {
        final fixture = _script([
          _Reply(selection('AI')),
          const _Reply({}, status: 503),
          _Reply(selection('AI', latest)),
        ]);
        final pending = ApiCallModelRepository(
          fixture.api,
        ).selectVoice('4', 'new');
        if (latest == 'new') {
          expect((await pending).activeVoice, 'new');
        } else {
          await expectLater(pending, throwsA(anything));
        }
        expect(fixture.requests.map((r) => r.method), ['GET', 'PUT', 'GET']);
      }
    },
  );

  test(
    'account change during activate cannot issue next-account reads',
    () async {
      final fixture = SyntheticAccountApi();
      addTearDown(fixture.api.close);
      fixture.beforeResponse = (_) async {
        fixture.credentials = const AccountCredentials('b', 'other', 2);
        fixture.data = {'active': true};
      };
      await expectLater(
        ApiCloneVoiceRepository(fixture.api).selectConfirmed('4'),
        throwsA(ApiFailure.sessionChanged),
      );
      expect(fixture.requests, hasLength(1));
    },
  );
}
