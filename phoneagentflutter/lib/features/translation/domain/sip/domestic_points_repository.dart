class DomesticPointsPricing {
  const DomesticPointsPricing({
    required this.provider,
    required this.modelId,
    required this.firstMinutePoints,
    required this.blockDurationMs,
    required this.blockPoints,
    required this.priceVersion,
  });
  final String provider, modelId, priceVersion;
  final int firstMinutePoints, blockDurationMs, blockPoints;
}

class DomesticPointsSession {
  const DomesticPointsSession({
    required this.id,
    required this.state,
    required this.authorizedThroughMs,
    required this.authorizationVersion,
    required this.connectedDurationMs,
    required this.chargedPoints,
    required this.availableBalance,
    required this.heldBalance,
    required this.stopState,
    this.stopAtDurationMs,
    this.pricing,
    this.displayDurationSeconds = 0,
    this.releasedPoints = 0,
    this.totalBalance = 0,
    this.ledgerId,
  });
  final String id, state, stopState;
  final int authorizedThroughMs,
      authorizationVersion,
      connectedDurationMs,
      chargedPoints,
      availableBalance,
      heldBalance,
      displayDurationSeconds,
      releasedPoints,
      totalBalance;
  final int? stopAtDurationMs, ledgerId;
  final DomesticPointsPricing? pricing;
  bool get settled =>
      const {'SETTLED', 'RELEASED'}.contains(state) && pricing != null;
}

enum DomesticPointsAction { connected, heartbeat, authorize, terminal }

class DomesticPointsEvent {
  const DomesticPointsEvent({
    required this.eventId,
    required this.sequence,
    required this.durationMs,
    required this.authorizationVersion,
    this.connected,
    this.mediaStoppedDurationMs,
    this.physicalEndedDurationMs,
    this.terminalReason,
  });
  final String eventId;
  final int sequence, durationMs, authorizationVersion;
  final bool? connected;
  final int? mediaStoppedDurationMs, physicalEndedDurationMs;
  final String? terminalReason;
  Map<String, Object?> toJson(DomesticPointsAction action) => {
    'eventId': eventId,
    'sequenceNo': sequence,
    'connectedDurationMs': durationMs,
    if (action == DomesticPointsAction.authorize)
      'expectedAuthorizationVersion': authorizationVersion
    else
      'authorizationVersion': authorizationVersion,
    if (action == DomesticPointsAction.terminal) ...{
      'connected': connected,
      'mediaStoppedDurationMs': mediaStoppedDurationMs,
      'physicalEndedDurationMs': physicalEndedDurationMs,
      'terminalReason': terminalReason,
    },
  };
}

abstract interface class DomesticPointsRepository {
  Future<DomesticPointsSession> create(String callId, String provider);
  Future<DomesticPointsSession> update(
    String sessionId,
    DomesticPointsAction action,
    DomesticPointsEvent event,
  );
}
