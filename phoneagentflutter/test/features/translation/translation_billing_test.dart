import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/translation/data/api_translation_billing_repository.dart';
import '../../support/synthetic_account_api.dart';

class DelayedBillingApi extends SyntheticAccountApi {
  final gate = Completer<void>();
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    await gate.future;
    return super.fetch(options, stream, cancel);
  }
}

void main() {
  test(
    'v65 aliases and only positive finite numeric overseas billing values are shown',
    () {
      final rates = ApiTranslationBillingRepository.decode({
        'providers': [
          {
            'provider': 'open-ai',
            'billingMultiplier': 1.25,
            'available': false,
          },
          {
            'provider': 'GOOGLE_GEMINI_LIVE_TRANSLATE',
            'billingMultiplier': 0.8,
          },
          {'provider': 'DOUBAO', 'billingMultiplier': 1},
          {'provider': 'UNKNOWN', 'billingMultiplier': 2},
        ],
      });
      expect(rates, {'OPENAI': 1.25, 'GEMINI': 0.8});
      expect(() => rates['OPENAI'] = 5, throwsUnsupportedError);
      for (final value in [null, '1.2', 0, -2, double.infinity, double.nan]) {
        expect(
          ApiTranslationBillingRepository.decode({
            'providers': [
              {'provider': 'GEMINI', 'billingMultiplier': value},
            ],
          }),
          isEmpty,
        );
      }
    },
  );
  test('malformed catalogs fail instead of displaying default rates', () {
    for (final payload in [
      null,
      {},
      {'providers': {}},
      {
        'providers': [1],
      },
      {
        'providers': [
          {'provider': 1},
        ],
      },
    ]) {
      expect(
        () => ApiTranslationBillingRepository.decode(payload),
        throwsA(ApiFailure.invalidResponse),
      );
    }
    expect(ApiTranslationBillingRepository.decode({'providers': []}), isEmpty);
  });
  test('account metadata uses account and bearer GET only; no PUT', () async {
    final fixture = SyntheticAccountApi()
      ..data = {
        'providers': [
          {'provider': 'OPENAI', 'billingMultiplier': 1.5},
        ],
      };
    addTearDown(fixture.api.close);
    expect(await ApiTranslationBillingRepository(fixture.api).load(), {
      'OPENAI': 1.5,
    });
    final request = fixture.requests.single;
    expect(request.method, 'GET');
    expect(
      request.uri.path,
      '/api/account/settings/realtime-translation-provider',
    );
    expect(request.headers['X-Account-Id'], 'a');
    expect(request.headers['Authorization'], 'Bearer synthetic');
    expect(request.data, isNull);
    expect(request.followRedirects, isFalse);
  });
  test('account transition during load cannot expose old rates', () async {
    final fixture = DelayedBillingApi()
      ..data = {
        'providers': [
          {'provider': 'GEMINI', 'billingMultiplier': 8},
        ],
      };
    addTearDown(fixture.api.close);
    final load = ApiTranslationBillingRepository(fixture.api).load();
    fixture.credentials = const AccountCredentials('b', 'synthetic-b', 2);
    fixture.gate.complete();
    await expectLater(load, throwsA(ApiFailure.sessionChanged));
  });
  test('network rejection does not turn into free/default billing', () async {
    final fixture = SyntheticAccountApi()..status = 500;
    addTearDown(fixture.api.close);
    await expectLater(
      ApiTranslationBillingRepository(fixture.api).load(),
      throwsA(ApiFailure.rejected),
    );
    expect(fixture.requests, hasLength(1));
  });
}
