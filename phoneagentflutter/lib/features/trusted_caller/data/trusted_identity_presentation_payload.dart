import 'dart:typed_data';
import '../domain/trusted_caller.dart';
import '../domain/trusted_incoming_identity.dart';
import 'trusted_incoming_identity_dto.dart';

/// Memory-only display snapshot. No SDK credentials or verification inputs.
abstract final class TrustedIdentityPresentationPayload {
  static Map<String, Object?> encode(
    TrustedIncomingIdentity value,
    String environment,
  ) => {
    'owner': {
      'accountId': value.owner.accountId,
      'phone': value.owner.phone,
      'loginEpoch': value.owner.loginEpoch,
      'environment': environment,
    },
    'eventId': value.eventId,
    'presentationId': value.presentationId,
    'presentationRevision': value.presentationRevision,
    'activityFresh': value.activityFresh,
    'identity': {
      'verification': value.verification.name,
      'showType': value.displayType.toString(),
      'name': value.name,
      'title': value.title,
      'deptZh': value.department,
      'position': value.position,
      'commonName': value.company,
      'phoneno': value.caller,
      'targetNumber': value.target,
      'sequence': value.sequence,
      'job': value.job,
      'school': value.school,
      'serialNumber': value.serial,
      'createTime': value.issuedAt,
      'organizationName': value.issuer,
      'callTime': value.callTime,
      'avatarData': Uint8List.fromList(value.avatarData),
    },
  };

  static TrustedIncomingIdentity? decode(Object? raw) {
    if (raw is! Map || raw['owner'] is! Map) return null;
    final owner = raw['owner'] as Map;
    if (owner['accountId'] is! String ||
        owner['phone'] is! String ||
        owner['loginEpoch'] is! int ||
        owner['environment'] is! String) {
      return null;
    }
    final value = TrustedIncomingIdentityDto.decode(
      raw,
      owner: TrustedCallerOwner(
        owner['accountId'] as String,
        owner['phone'] as String,
        owner['loginEpoch'] as int,
      ),
      environment: owner['environment'] as String,
    );
    return value?.presentationId == raw['presentationId'] ? value : null;
  }
}
