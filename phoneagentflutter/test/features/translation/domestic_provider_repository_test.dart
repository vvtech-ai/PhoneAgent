import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/data/sip/api_domestic_provider_repository.dart';
import '../../support/synthetic_account_api.dart';

Map<String, Object?> catalog(String active) => {
  'activeProvider': active,
  'providers': [
    {
      'provider': 'QWEN_OMNI_PLUS',
      'active': active == 'QWEN_OMNI_PLUS',
      'configured': true,
      'available': true,
      'statusMessage': '',
      'billingMultiplier': 2,
    },
    {
      'provider': 'DOUBAO',
      'active': active == 'DOUBAO',
      'configured': true,
      'available': true,
      'statusMessage': '',
      'billingMultiplier': 1,
    },
  ],
};
void main() {
  test(
    'native GET/PUT preserve wire ID, canonical engine and account-only auth',
    () async {
      final http = SyntheticAccountApi();
      addTearDown(http.api.close);
      http.data = catalog('QWEN_OMNI_PLUS');
      final repo = ApiDomesticProviderRepository(http.api);
      final first = await repo.load();
      expect(first.activeEngine, 'QWEN');
      expect(first.current.displayName, 'QWEN_OMNI_PLUS');
      expect(http.requests.first.uri.queryParameters, {'region': 'DOMESTIC'});
      expect(first.current.billingMultiplier, 2);
      http.data = catalog('DOUBAO');
      final changed = await repo.select('DOUBAO');
      expect(changed.activeEngine, 'DOUBAO');
      expect(http.requests.last.method, 'PUT');
      expect(http.requests.last.data, {
        'region': 'DOMESTIC',
        'provider': 'DOUBAO',
      });
      expect(http.requests.last.headers['X-Account-Id'], 'a');
      expect(http.requests.last.headers['Authorization'], 'Bearer synthetic');
    },
  );
  test(
    'unconfirmed choice, malformed flags, ambiguous aliases and negative rate refuse',
    () async {
      final http = SyntheticAccountApi();
      addTearDown(http.api.close);
      final repo = ApiDomesticProviderRepository(http.api);
      http.data = catalog('QWEN_OMNI_PLUS');
      await expectLater(repo.select('DOUBAO'), throwsA(anything));
      final wrong = catalog('QWEN_OMNI_PLUS');
      ((wrong['providers'] as List).first as Map)['available'] = 'yes';
      expect(
        () => ApiDomesticProviderRepository.decode(wrong),
        throwsA(anything),
      );
      final rate = catalog('QWEN_OMNI_PLUS');
      ((rate['providers'] as List).first as Map)['billingMultiplier'] = -1;
      expect(
        () => ApiDomesticProviderRepository.decode(rate),
        throwsA(anything),
      );
      final aliases = catalog('QWEN_OMNI_PLUS');
      (aliases['providers'] as List).add({
        'provider': 'QWEN',
        'active': false,
        'configured': true,
        'available': true,
        'statusMessage': '',
      });
      expect(ApiDomesticProviderRepository.decode(aliases).options.length, 3);
    },
  );
}
