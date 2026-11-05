import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/data/sip/api_domestic_points_repository.dart';
import 'package:phone_agent/features/translation/domain/sip/domestic_points_repository.dart';
import '../../support/synthetic_account_api.dart';

void main() {
  late SyntheticAccountApi api;
  late ApiDomesticPointsRepository repo;
  late Map<String, Object?> data;
  setUp(() {
    api = SyntheticAccountApi();
    repo = ApiDomesticPointsRepository(api.api);
    data = {
      'billingSessionId': 'synthetic-billing',
      'sessionState': 'PREPARED',
      'authorizedThroughMs': 60000,
      'authorizationVersion': 1,
      'connectedDurationMs': 0,
      'chargedPoints': 0,
      'availableBalance': 600,
      'heldBalance': 150,
      'stopState': 'NONE',
      'stopAtDurationMs': null,
      'pricing': {
        'provider': 'QWEN',
        'modelId': 'QWEN',
        'firstMinutePoints': 150,
        'blockDurationMs': 6000,
        'blockPoints': 15,
        'priceVersion': 'synthetic-v1',
      },
    };
    api.data = data;
  });
  tearDown(() => api.api.close());
  test('billing submits exact selected model ID', () async {
    (data['pricing'] as Map)['modelId'] = 'qwen-custom-second';
    final session = await repo.create('synthetic-call', 'qwen-custom-second');
    expect((api.requests.single.data as Map)['modelId'], 'qwen-custom-second');
    expect(session.pricing?.modelId, 'qwen-custom-second');
  });
  const event = DomesticPointsEvent(
    eventId: 'synthetic-call:authorize:2',
    sequence: 3,
    durationMs: 55000,
    authorizationVersion: 1,
  );
  test(
    'create uses native identity and standard idempotency, authorized snapshot',
    () async {
      final session = await repo.create('synthetic-call', 'QWEN');
      expect(session.authorizedThroughMs, 60000);
      expect(session.pricing!.blockPoints, 15);
      expect(
        api.requests.single.headers['Idempotency-Key'],
        'translation:synthetic-call',
      );
      expect(api.requests.single.data, {
        'usageType': 'TRANSLATION_CALL',
        'businessId': 'synthetic-call',
        'clientCallId': 'synthetic-call',
        'transport': 'LOCAL_SIP',
        'modelId': 'QWEN',
        'callId': 'synthetic-call',
      });
    },
  );
  test(
    'authorize uses expected version and rejects mismatched billing owner',
    () async {
      await repo.update(
        'synthetic-billing',
        DomesticPointsAction.authorize,
        event,
      );
      expect(api.requests.single.data, {
        'eventId': event.eventId,
        'sequenceNo': 3,
        'connectedDurationMs': 55000,
        'expectedAuthorizationVersion': 1,
      });
      data['billingSessionId'] = 'other-billing';
      await expectLater(
        repo.update('synthetic-billing', DomesticPointsAction.heartbeat, event),
        throwsA(anything),
      );
    },
  );
  test(
    'invalid duration/price cannot grant a call and no unknown automatic retry',
    () async {
      data['authorizedThroughMs'] = -1;
      await expectLater(
        repo.create('synthetic-call', 'QWEN'),
        throwsA(anything),
      );
      expect(api.requests.length, 1);
      data['authorizedThroughMs'] = 60000;
      (data['pricing'] as Map)['blockDurationMs'] = 0;
      await expectLater(
        repo.create('synthetic-call-2', 'QWEN'),
        throwsA(anything),
      );
      expect(api.requests.length, 2);
    },
  );
  test(
    'terminal success requires final state and pricing, rejects unsafe resource before HTTP',
    () async {
      final prepared = await repo.create('synthetic-call', 'QWEN');
      expect(prepared.settled, false);
      data['sessionState'] = 'SETTLED';
      final finalState = await repo.create('synthetic-call', 'QWEN');
      expect(finalState.settled, true);
      data['pricing'] = null;
      expect((await repo.create('synthetic-call', 'QWEN')).settled, false);
      final count = api.requests.length;
      await expectLater(
        repo.update('../unsafe', DomesticPointsAction.heartbeat, event),
        throwsA(anything),
      );
      expect(api.requests.length, count);
    },
  );
}
