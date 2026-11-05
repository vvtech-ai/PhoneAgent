import '../domain/membership_entitlements.dart';
import 'commerce_dto.dart';

class MembershipV2Dto {
  static const types = ['NEW', 'UPGRADE', 'RENEW', 'LOWER_QUEUED'];
  static const states = ['ACTIVE', 'PAUSED', 'QUEUED', 'EXHAUSTED', 'REVOKED'];
  static String id(Map<String, Object?> m, String key) {
    final value = CommerceDto.text(m, key);
    if (!RegExp(r'^\d+$').hasMatch(value)) {
      throw FormatException('Invalid $key');
    }
    return value;
  }

  static int number(Map<String, Object?> m, String key) {
    final n = CommerceDto.integer(m, key);
    if (n > 9007199254740991) throw FormatException('Unsafe $key');
    return n;
  }

  static List<MembershipQueueItem> items(Object? value) {
    if (value is! List) throw const FormatException('Invalid membership queue');
    return List.unmodifiable(value.map(item));
  }

  static MembershipQueueItem item(Object? value) {
    final m = CommerceDto.object(value);
    return MembershipQueueItem(
      entitlementId: id(m, 'entitlementId'),
      sourceOrderNo: CommerceDto.text(m, 'sourceOrderNo'),
      level: CommerceDto.oneOf(m, 'level', ['BASIC', 'PLUS', 'PREMIUM']),
      months: number(m, 'months'),
      state: CommerceDto.oneOf(m, 'state', states),
      position: number(m, 'position'),
      firstGrantPoints: number(m, 'firstGrantPoints'),
      totalPeriods: number(m, 'totalPeriods'),
      grantedPeriods: number(m, 'grantedPeriods'),
      remainingSeconds: m['remainingSeconds'] == null
          ? null
          : number(m, 'remainingSeconds'),
      firstActivatedAt: CommerceDto.optionalDate(m, 'firstActivatedAt'),
      currentExpiresAt: CommerceDto.optionalDate(m, 'currentExpiresAt'),
      estimatedStartsAt: CommerceDto.optionalDate(m, 'estimatedStartsAt'),
      estimatedExpiresAt: CommerceDto.optionalDate(m, 'estimatedExpiresAt'),
      nextGrantAt: CommerceDto.optionalDate(m, 'nextGrantAt'),
    );
  }

  static MembershipPurchasePreview preview(Object? value) {
    final m = CommerceDto.object(value);
    return MembershipPurchasePreview(
      ruleVersion: CommerceDto.oneOf(m, 'ruleVersion', ['PAUSE_QUEUE_V1']),
      purchaseType: CommerceDto.oneOf(m, 'purchaseType', types),
      targetLevel: CommerceDto.oneOf(m, 'targetLevel', [
        'BASIC',
        'PLUS',
        'PREMIUM',
      ]),
      targetMonths: number(m, 'targetMonths'),
      immediateGrantPoints: number(m, 'immediateGrantPoints'),
      firstGrantPoints: number(m, 'firstGrantPoints'),
      basePointsPerPeriod: number(m, 'basePointsPerPeriod'),
      bonusPointsPerPeriod: number(m, 'bonusPointsPerPeriod'),
      totalPeriods: number(m, 'totalPeriods'),
      activationTiming: CommerceDto.oneOf(m, 'activationTiming', [
        'IMMEDIATE',
        'AFTER_QUEUE',
      ]),
      membershipVersion: id(m, 'membershipVersion'),
      precedingEntitlements: items(m['precedingEntitlements']),
      pausedEntitlement: m['pausedEntitlement'] == null
          ? null
          : item(m['pausedEntitlement']),
      estimatedStartsAt: CommerceDto.optionalDate(m, 'estimatedStartsAt'),
      estimatedExpiresAt: CommerceDto.optionalDate(m, 'estimatedExpiresAt'),
    );
  }

  static MembershipFulfillment fulfillment(Object? value) {
    final m = CommerceDto.object(value);
    return MembershipFulfillment(
      ruleVersion: CommerceDto.oneOf(m, 'ruleVersion', ['PAUSE_QUEUE_V1']),
      actualPurchaseType: CommerceDto.oneOf(m, 'actualPurchaseType', types),
      entitlementId: id(m, 'entitlementId'),
      initialEntitlementState: CommerceDto.oneOf(
        m,
        'initialEntitlementState',
        states,
      ),
      entitlementState: CommerceDto.oneOf(m, 'entitlementState', states),
      fulfillmentDecisionAt: CommerceDto.date(m, 'fulfillmentDecisionAt'),
      activatedAt: CommerceDto.optionalDate(m, 'activatedAt'),
      initialGrantedPoints: number(m, 'initialGrantedPoints'),
      firstActivationGrantedPoints: m['firstActivationGrantedPoints'] == null
          ? null
          : number(m, 'firstActivationGrantedPoints'),
      queuedFirstGrantPoints: number(m, 'queuedFirstGrantPoints'),
      totalPeriods: number(m, 'totalPeriods'),
    );
  }
}
