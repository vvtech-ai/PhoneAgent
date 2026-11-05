import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/call_model_quality_providers.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/core/network/account_api.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/call_models/data/api_call_model_quality_repository.dart';
import 'package:phone_agent/features/call_models/domain/call_model_quality.dart';

class _Session implements AccountSession {
  AccountCredentials current = const AccountCredentials(
    'synthetic',
    'synthetic',
    1,
  );
  @override
  AccountCredentials get credentials => current;
  @override
  Future<bool> replaceToken(AccountCredentials expected, String token) async =>
      false;
  @override
  Future<void> rejectSession(AccountCredentials expected) async {}
}

class _Port implements CallModelQualityRepository {
  final pending = <Completer<Map<String, CallModelReading>>>[];
  @override
  Future<Map<String, CallModelReading>> refresh() {
    final next = Completer<Map<String, CallModelReading>>();
    pending.add(next);
    return next.future;
  }
}

void main() {
  test(
    'native GET refresh query uses account API and rejects late account response',
    () async {
      final session = _Session();
      final dio = Dio();
      var requestReady = Completer<void>();
      late RequestOptions captured;
      late RequestInterceptorHandler pending;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            captured = request;
            pending = handler;
            requestReady.complete();
          },
        ),
      );
      final api = AccountApi(
        AppConfig.parse(
          environment: 'dev',
          apiBaseUrl: 'https://example.test/',
          sdkApiBaseUrl: 'https://example.test/sdk/',
        ),
        session,
        client: dio,
      );
      final port = ApiCallModelQualityRepository(api);
      final result = port.refresh();
      await requestReady.future;
      expect(captured.method, 'GET');
      expect(captured.uri.path, '/api/assistant/realtime/call-models/latency');
      expect(captured.uri.queryParameters, {'refresh': 'true'});
      expect(captured.headers['X-Account-Id'], 'synthetic');
      expect(captured.headers['Authorization'], 'Bearer synthetic');
      pending.resolve(
        Response(
          requestOptions: captured,
          statusCode: 200,
          data: {
            'code': 0,
            'data': {
              'models': [
                {
                  'provider': 'QWEN_OMNI_PLUS',
                  'available': true,
                  'latencyMs': 199,
                },
              ],
            },
          },
        ),
      );
      expect((await result)['QWEN_OMNI_PLUS']!.latencyMs, 199);
      requestReady = Completer<void>();
      final late = port.refresh();
      final rejected = expectLater(late, throwsA(ApiFailure.sessionChanged));
      await requestReady.future;
      session.current = const AccountCredentials(
        'other-synthetic',
        'synthetic',
        2,
      );
      pending.resolve(
        Response(
          requestOptions: captured,
          statusCode: 200,
          data: {
            'code': 0,
            'data': {'models': []},
          },
        ),
      );
      await rejected;
      api.close();
    },
  );
  test(
    'quality provider account epoch disposes old owner and ignores its response',
    () async {
      final epoch = StateProvider<int>((ref) => 1);
      final port = _Port();
      final container = ProviderContainer(
        overrides: [
          loginEpochProvider.overrideWith((ref) => ref.watch(epoch)),
          callModelQualityRepositoryProvider.overrideWithValue(port),
        ],
      );
      final subscription = container.listen(
        callModelQualityProvider,
        (_, __) {},
      );
      final old = container.read(callModelQualityProvider.notifier);
      final pending = old.refresh(['OLD']);
      container.read(epoch.notifier).state = 2;
      final newer = container.read(callModelQualityProvider.notifier);
      expect(identical(newer, old), isFalse);
      port.pending.single.complete({
        'OLD': CallModelReading.probe(available: true, latencyMs: 10),
      });
      await pending;
      expect(newer.state.readings, isEmpty);
      expect(newer.state.busy, isFalse);
      subscription.close();
      container.dispose();
    },
  );
}
