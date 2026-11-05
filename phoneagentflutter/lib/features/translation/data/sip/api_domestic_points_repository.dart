import '../../../../core/network/account_api.dart';
import '../../../../core/network/account_session.dart';
import '../../domain/sip/domestic_points_repository.dart';
import '../../domain/sip/sip_lease.dart';

class ApiDomesticPointsRepository implements DomesticPointsRepository {
  const ApiDomesticPointsRepository(this.api);
  final AccountApi api;
  static const _path = 'api/points/usage-sessions';
  @override
  Future<DomesticPointsSession> create(String callId, String provider) async {
    if (!validSipResourceId(callId) ||
        callId.length > 116 ||
        !RegExp(r'^[A-Za-z0-9_.:-]{1,100}$').hasMatch(provider)) {
      throw ApiFailure.invalidResponse;
    }
    return _parse(
      AccountApi.object(
        await api.request(
          _path,
          method: 'POST',
          idempotencyKey: 'translation:$callId',
          idempotencyHeader: AccountIdempotencyHeader.standard,
          exposedCodes: const {'POINTS_INSUFFICIENT_BALANCE'},
          body: {
            'usageType': 'TRANSLATION_CALL',
            'businessId': callId,
            'clientCallId': callId,
            'transport': 'LOCAL_SIP',
            'modelId': provider,
            'callId': callId,
          },
        ),
      ),
    );
  }

  @override
  Future<DomesticPointsSession> update(
    String sessionId,
    DomesticPointsAction action,
    DomesticPointsEvent event,
  ) async {
    if (!validSipResourceId(sessionId) ||
        !RegExp(r'^[A-Za-z0-9_:-]{1,256}$').hasMatch(event.eventId) ||
        event.sequence < 1 ||
        event.durationMs < 0 ||
        event.authorizationVersion < 0 ||
        (action == DomesticPointsAction.terminal &&
            (event.connected == null ||
                event.terminalReason == null ||
                event.terminalReason!.isEmpty ||
                event.terminalReason!.length > 120 ||
                event.terminalReason!.contains(RegExp(r'[\r\n\x00]')) ||
                (event.connected! &&
                    (event.mediaStoppedDurationMs == null ||
                        event.physicalEndedDurationMs == null ||
                        event.mediaStoppedDurationMs! < 0 ||
                        event.physicalEndedDurationMs! <
                            event.mediaStoppedDurationMs!))))) {
      throw ApiFailure.invalidResponse;
    }
    final suffix = switch (action) {
      DomesticPointsAction.connected => 'connected',
      DomesticPointsAction.heartbeat => 'heartbeat',
      DomesticPointsAction.authorize => 'authorize-next',
      DomesticPointsAction.terminal => 'terminal',
    };
    final session = _parse(
      AccountApi.object(
        await api.request(
          '$_path/$sessionId/$suffix',
          method: 'POST',
          body: event.toJson(action),
        ),
      ),
    );
    if (session.id != sessionId) {
      throw ApiFailure.invalidResponse;
    }
    return session;
  }

  static DomesticPointsSession _parse(Map<String, Object?> data) {
    String text(Map<String, Object?> object, String key) {
      final value = object[key];
      if (value is! String ||
          value.isEmpty ||
          value.length > 256 ||
          value.contains(RegExp(r'[\r\n\x00]'))) {
        throw ApiFailure.invalidResponse;
      }
      return value;
    }

    int integer(
      Map<String, Object?> object,
      String key, {
      bool optional = false,
    }) {
      final value = object[key];
      if (value == null && optional) {
        return 0;
      }
      if (value is! int || value < 0 || value > 9007199254740991) {
        throw ApiFailure.invalidResponse;
      }
      return value;
    }

    final id = text(data, 'billingSessionId');
    if (!validSipResourceId(id)) {
      throw ApiFailure.invalidResponse;
    }
    final rawPricing = data['pricing'];
    DomesticPointsPricing? pricing;
    if (rawPricing != null) {
      final value = AccountApi.object(rawPricing);
      pricing = DomesticPointsPricing(
        provider: text(value, 'provider'),
        modelId: text(value, 'modelId'),
        firstMinutePoints: integer(value, 'firstMinutePoints'),
        blockDurationMs: integer(value, 'blockDurationMs'),
        blockPoints: integer(value, 'blockPoints'),
        priceVersion: text(value, 'priceVersion'),
      );
      if (pricing.blockDurationMs == 0) {
        throw ApiFailure.invalidResponse;
      }
    }
    return DomesticPointsSession(
      id: id,
      state: text(data, 'sessionState'),
      authorizedThroughMs: integer(data, 'authorizedThroughMs'),
      authorizationVersion: integer(data, 'authorizationVersion'),
      connectedDurationMs: integer(data, 'connectedDurationMs'),
      chargedPoints: integer(data, 'chargedPoints'),
      availableBalance: integer(data, 'availableBalance'),
      heldBalance: integer(data, 'heldBalance'),
      stopState: text(data, 'stopState'),
      stopAtDurationMs: data['stopAtDurationMs'] == null
          ? null
          : integer(data, 'stopAtDurationMs'),
      pricing: pricing,
      displayDurationSeconds: integer(
        data,
        'displayDurationSeconds',
        optional: true,
      ),
      releasedPoints: integer(data, 'releasedPoints', optional: true),
      totalBalance: integer(data, 'totalBalance', optional: true),
      ledgerId: data['ledgerId'] == null ? null : integer(data, 'ledgerId'),
    );
  }
}
