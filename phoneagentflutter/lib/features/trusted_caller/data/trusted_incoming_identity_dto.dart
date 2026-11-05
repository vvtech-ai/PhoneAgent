import 'dart:typed_data';
import '../domain/trusted_caller.dart';
import '../domain/trusted_incoming_identity.dart';

class TrustedIncomingIdentityDto {
  static TrustedIncomingIdentity? decode(
    Object? event, {
    required TrustedCallerOwner owner,
    required String environment,
  }) {
    if (event is! Map || !owner.valid) return null;
    final rawOwner = event['owner'], identity = event['identity'];
    if (rawOwner is! Map || identity is! Map) return null;
    if (rawOwner['accountId'] != owner.accountId ||
        rawOwner['phone'] != owner.phone ||
        rawOwner['loginEpoch'] is! int ||
        rawOwner['loginEpoch'] != owner.loginEpoch ||
        rawOwner['environment'] != environment ||
        !{'test', 'pro'}.contains(environment)) {
      return null;
    }
    final eventId = event['eventId'];
    if (eventId is! String ||
        !RegExp(
          r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$',
        ).hasMatch(eventId) ||
        event['activityFresh'] is! bool) {
      return null;
    }
    final verification = TrustedIdentityVerification.values
        .where((value) => value.name == identity['verification'])
        .firstOrNull;
    if (verification == null) return null;
    final revision = event['presentationRevision'] ?? 0;
    if (revision is! int || revision < 0 || revision > 2147483647) {
      return null;
    }
    String field(List<String> keys) {
      for (final key in keys) {
        final raw = identity[key];
        if (raw is! String) continue;
        final value = raw.trim();
        if (value.isNotEmpty &&
            value.length <= 1024 &&
            !RegExp(r'[\x00-\x1f\x7f]').hasMatch(value)) {
          return value;
        }
      }
      return '';
    }

    final displayType = int.tryParse(field(['showType', 'identityType'])) ?? 0;
    final effectiveVerification =
        displayType == 6 && verification == TrustedIdentityVerification.verified
        ? TrustedIdentityVerification.uncertified
        : verification;
    final activityFresh = event['activityFresh'] as bool;
    if (activityFresh &&
        !{
          TrustedIdentityVerification.verified,
          TrustedIdentityVerification.uncertified,
        }.contains(effectiveVerification)) {
      return null;
    }
    final caller = field(['phoneno']);
    final target = field(['targetNumber']);
    final sequence = field(['sequence']);
    if (caller.isEmpty || target.isEmpty || sequence.isEmpty) return null;
    String normalized(String phone) {
      final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
      return digits.length == 13 && digits.startsWith('86')
          ? digits.substring(2)
          : digits;
    }

    if (target != owner.phone &&
        (normalized(owner.phone).isEmpty ||
            normalized(target) != normalized(owner.phone))) {
      return null;
    }
    return TrustedIncomingIdentity(
      avatarData:
          identity['avatarData'] is Uint8List &&
              (identity['avatarData'] as Uint8List).length <= 32768
          ? List<int>.unmodifiable(identity['avatarData'] as Uint8List)
          : const [],
      owner: owner,
      eventId: eventId,
      presentationRevision: revision,
      verification: effectiveVerification,
      displayType: displayType,
      activityFresh: activityFresh,
      name: field(['name', 'userName', 'realName']),
      title: field(['title']),
      department: field(['deptZh', 'dept', 'department']),
      position: field(['position', 'job', 'jobTitle']),
      company: field(['commonName', 'companyName', 'organizationName']),
      caller: caller,
      target: target,
      sequence: sequence,
      job: field(['job']),
      school: field(['school']),
      serial: field(['serialNumber', 'UniqueID', 'sequence']),
      issuedAt: field(['createTime', 'callTime', 'complaintTime']),
      issuer: field(['organizationName', 'caName', 'caType']),
      callTime: field(['callTime', 'createTime']),
    );
  }
}
