import 'sip/domestic_points_repository.dart';

String domesticSettlementNotice(DomesticPointsSession? session) {
  if (session == null ||
      !session.settled ||
      session.state != 'SETTLED' ||
      session.connectedDurationMs <= 0 ||
      session.chargedPoints <= 0 ||
      session.availableBalance < 0) {
    return '';
  }
  return '本次扣除 ✦${session.chargedPoints} 积分，剩余 ✦${session.availableBalance} 积分';
}
