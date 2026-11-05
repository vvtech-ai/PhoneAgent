import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/core/network/account_api.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/apology/data/api_apology_voice_port.dart';
import 'package:phone_agent/features/apology/presentation/controller/apology_conversation_binding.dart';
import 'package:phone_agent/features/apology/domain/apology_voice.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import '../../../tool/previews/shell_conversation_fakes.dart';

class _Session implements AccountSession {
  @override
  AccountCredentials? credentials = const AccountCredentials(
    'synthetic',
    'synthetic',
    1,
  );
  @override
  Future<bool> replaceToken(AccountCredentials expected, String token) async =>
      false;
  @override
  Future<void> rejectSession(AccountCredentials expected) async {}
}

class _Adapter implements HttpClientAdapter {
  Object body = {};
  Object catalog = {};
  Object Function(RequestOptions)? response;
  Completer<void>? pending;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions r,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    requests.add(r);
    await pending?.future;
    return ResponseBody.fromString(
      jsonEncode({
        'code': 0,
        'data':
            response?.call(r) ??
            (r.path.endsWith('/commerce/catalog') ? catalog : body),
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, Object?> _model(
  String id, {
  bool usable = true,
  bool available = true,
  String status = 'READY',
  String candidateModel = '2',
}) => {
  'modelId': id,
  'displayName': '模型$id',
  'available': available,
  'cloneEntitled': true,
  'current': {
    'modelId': id,
    'status': status,
    'usable': usable,
    'providerAssetId': 'asset-$id',
    'active': false,
  },
  'candidate': {
    'modelId': candidateModel,
    'status': 'READY',
    'billingStatus': 'CHARGED',
    'providerAssetId': 'candidate',
  },
};
void main() {
  late AccountApi api;
  late ApiApologyVoicePort port;
  late _Adapter adapter;
  late _Session session;
  setUp(() {
    adapter = _Adapter();
    session = _Session();
    api = AccountApi(
      AppConfig.parse(
        environment: 'dev',
        apiBaseUrl: 'https://example.test/aiassistant-api/',
      ),
      session,
      client: Dio()..httpClientAdapter = adapter,
    );
    port = ApiApologyVoicePort(api);
  });
  tearDown(() => api.close());
  Future<void> flush() async {
    for (var i = 0; i < 50; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  for (final afterConfirm in [false, true]) {
    test(
      'fresh candidate permission withdrawal remains normal empty: afterConfirm=$afterConfirm',
      () async {
        final gateway = OfflineAgent();
        var confirmed = false;
        adapter.body = {
          'models': [_model('2', usable: false)],
        };
        final controller = ConversationController(
          entry: const ConversationEntry(
            sessionId: 'permission',
            skillId: 'apology_master',
          ),
          accountId: 'synthetic',
          gateway: gateway,
          history: OfflineHistory(),
          apologyVoice: ApologyVoiceDependencies(
            port: port,
            model: () => '2',
            modelName: () => '模型2',
          ),
        );
        addTearDown(controller.dispose);
        controller.send('确认使用');
        await flush();
        expect(controller.apology!.voice.stage, ApologyVoiceStage.modelConsent);
        final stale = controller.state.activeOptionsId!;
        if (afterConfirm) {
          adapter.response = (r) {
            if (r.uri.path.endsWith('/candidate/confirm')) {
              confirmed = true;
              return {
                'modelId': '2',
                'providerAssetId': 'candidate',
                'status': 'CONFIRMED',
              };
            }
            return {
              'models': [
                _model('2', usable: false)..['cloneEntitled'] = !confirmed,
              ],
            };
          };
        } else {
          adapter.body = {
            'models': [_model('2', usable: false)..['cloneEntitled'] = false],
          };
        }
        controller.send('确认使用');
        await flush();
        expect(controller.apology!.voice.selection, isNull);
        expect(controller.apology!.voice.stage, ApologyVoiceStage.needsVoice);
        expect(controller.apology!.voice.prompt!.text, contains('没有您的可用克隆音色'));
        expect(controller.apology!.voice.prompt!.choices.map((c) => c.id), [
          'decline',
        ]);
        expect(confirmed, afterConfirm);
        expect(controller.choose(stale, 0), isFalse);
        controller.send('确认使用');
        controller.send('继续道歉');
        expect(gateway.commands, isEmpty);
      },
    );
  }
  test(
    'unpublished evidence is shared within a read and refreshed on next read',
    () async {
      adapter.body = {
        'models': [
          _model('1')..remove('cloneEntitled'),
          _model('2')..remove('cloneEntitled'),
        ],
      };
      adapter.catalog = {'configVersionId': 0};
      expect(await port.voices(), hasLength(2));
      expect(
        adapter.requests.where((r) => r.path.endsWith('/commerce/catalog')),
        hasLength(1),
      );
      adapter.catalog = {'configVersionId': 4};
      await expectLater(port.voices(), throwsA(ApiFailure.invalidResponse));
      expect(
        adapter.requests.where((r) => r.path.endsWith('/commerce/catalog')),
        hasLength(2),
      );
    },
  );
  test(
    'confirmed candidate still pending visibility remains retryable',
    () async {
      adapter.body = {
        'models': [_model('2', usable: false)],
      };
      final controller = ConversationController(
        entry: const ConversationEntry(
          sessionId: 'visibility',
          skillId: 'apology_master',
        ),
        accountId: 'synthetic',
        gateway: OfflineAgent(),
        history: OfflineHistory(),
        apologyVoice: ApologyVoiceDependencies(
          port: port,
          model: () => '2',
          modelName: () => '模型2',
        ),
      );
      addTearDown(controller.dispose);
      controller.send('确认使用');
      await flush();
      adapter.response = (r) => r.uri.path.endsWith('/candidate/confirm')
          ? {
              'modelId': '2',
              'providerAssetId': 'candidate',
              'status': 'CONFIRMED',
            }
          : adapter.body;
      controller.send('确认使用');
      await flush();
      expect(controller.apology!.voice.selection, isNull);
      expect(
        controller.apology!.voice.prompt!.choices.map((c) => c.id),
        contains('retry'),
      );
    },
  );
  for (final close in [false, true]) {
    test(
      'late permission result cannot revive closed or changed account: close=$close',
      () async {
        adapter.body = {
          'models': [_model('2')],
        };
        final gateway = OfflineAgent();
        final controller = ConversationController(
          entry: const ConversationEntry(
            sessionId: 'late',
            skillId: 'apology_master',
          ),
          accountId: 'synthetic',
          gateway: gateway,
          history: OfflineHistory(),
          accountIsCurrent: () => session.credentials?.epoch == 1,
          apologyVoice: ApologyVoiceDependencies(
            port: port,
            model: () => '2',
            modelName: () => '模型2',
          ),
        );
        addTearDown(controller.dispose);
        adapter.pending = Completer<void>();
        controller.send('确认使用');
        await flush();
        expect(controller.apology!.voice.stage, ApologyVoiceStage.checking);
        final prompt = controller.apology!.voice.prompt;
        if (close) {
          controller.close();
        } else {
          session.credentials = const AccountCredentials(
            'other',
            'synthetic',
            2,
          );
        }
        adapter.pending!.complete();
        await flush();
        expect(controller.apology!.voice.selection, isNull);
        expect(controller.apology!.voice.prompt, same(prompt));
        expect(gateway.commands, isEmpty);
        expect(controller.isOpen, isFalse);
      },
    );
  }
  for (final candidate in [false, true]) {
    test(
      'ready asset cannot override denied clone entitlement: candidate=$candidate',
      () async {
        adapter.body = {
          'models': [
            _model('2', usable: !candidate)..['cloneEntitled'] = false,
          ],
        };
        expect(await port.voices(), isEmpty);
        expect(adapter.requests, hasLength(1));
      },
    );
  }
  for (final version in [null, 0, 1, '0']) {
    test(
      'missing entitlement needs explicit unpublished catalog evidence: $version',
      () async {
        adapter.body = {
          'models': [_model('1')..remove('cloneEntitled')],
        };
        adapter.catalog = {'configVersionId': version};
        if (version == 0) {
          expect((await port.voices()).single.modelId, '1');
        } else {
          await expectLater(port.voices(), throwsA(ApiFailure.invalidResponse));
        }
        expect(adapter.requests.last.uri.path, endsWith('/commerce/catalog'));
      },
    );
  }
  test(
    'unavailable entitlement is a retryable read failure even for ready assets',
    () async {
      adapter.body = {
        'models': [
          _model('1')..addAll({
            'cloneEntitled': false,
            'entitlementReason': 'ENTITLEMENT_UNAVAILABLE',
          }),
        ],
      };
      await expectLater(port.voices(), throwsA(ApiFailure.invalidResponse));
    },
  );
  test(
    'only same-model ready usable current or charged candidate is eligible',
    () async {
      adapter.body = {
        'models': [
          _model('1'),
          _model('2', usable: false),
          _model('3', available: false),
          _model('4', status: 'PROCESSING', candidateModel: 'other'),
        ],
      };
      final voices = await port.voices();
      expect(voices.map((v) => v.modelId), ['1', '2']);
      expect(voices.first.candidate, isFalse);
      expect(voices.last.candidate, isTrue);
      expect(adapter.requests.single.uri.path, endsWith('/voice-clone/models'));
      adapter.body = {
        'modelId': '2',
        'providerAssetId': 'candidate',
        'status': 'CONFIRMED',
      };
      await port.confirmCandidate(voices.last);
      expect(adapter.requests.last.uri.queryParameters, {'activate': 'false'});
      expect(adapter.requests.last.method, 'POST');
      expect(
        adapter.requests.where((r) => r.uri.path.endsWith('/activate')),
        isEmpty,
      );
    },
  );
  test('another asset confirmation and switched account fail closed', () async {
    adapter.body = {
      'models': [_model('2', usable: false)],
    };
    final voice = (await port.voices()).single;
    adapter.body = {
      'modelId': '2',
      'providerAssetId': 'wrong',
      'status': 'CONFIRMED',
    };
    await expectLater(
      port.confirmCandidate(voice),
      throwsA(ApiFailure.invalidResponse),
    );
    session.credentials = const AccountCredentials('other', 'other', 2);
    await expectLater(port.voices(), throwsA(ApiFailure.sessionChanged));
  });
}
