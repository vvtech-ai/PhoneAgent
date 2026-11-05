import '../domain/invite.dart';
import '../domain/invite_link_policy.dart';
import 'invite_protocol_diagnostics.dart';
import 'published_invite_link.dart';

Map<String, dynamic> inviteObject(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const InviteFailure('INVALID_RESPONSE');
  }
  return value;
}

String inviteText(Map<String, dynamic> m, String k, {bool optional = false}) {
  final v = m[k];
  if (optional && v == null) return '';
  if (v is! String || (!optional && v.isEmpty)) {
    throw const InviteFailure('INVALID_RESPONSE');
  }
  return v;
}

int inviteInt(Map<String, dynamic> m, String k) {
  final v = m[k];
  if (v is! int || v < 0) throw const InviteFailure('INVALID_RESPONSE');
  return v;
}

InviteOverview inviteOverview(Map<String, dynamic> data) {
  final raw = data['activity'];
  InviteActivity? activity;
  if (raw != null) {
    final a = inviteObject(raw);
    activity = InviteActivity(
      id: inviteText(a, 'periodId'),
      name: inviteText(a, 'name'),
      rules: inviteText(a, 'rulesTemplate', optional: true),
      inviterPoints: inviteInt(a, 'inviterPoints'),
      inviteePoints: inviteInt(a, 'inviteePoints'),
      quota: inviteInt(a, 'quotaPerInviter'),
      subtitle: inviteText(a, 'subtitle', optional: true),
      startAt: inviteText(a, 'startAt', optional: true),
      endAt: inviteText(a, 'endAt', optional: true),
      longTerm: a['longTerm'] == true,
      bonusEnabled: a['fullBonusEnabled'] == true,
      bonusThreshold: a['fullBonusEnabled'] == true
          ? inviteInt(a, 'fullBonusThreshold')
          : 0,
      bonusPoints: a['fullBonusEnabled'] == true
          ? inviteInt(a, 'fullBonusPoints')
          : 0,
    );
  }
  InvitePersonal? personal;
  if (data['personal'] != null) {
    final p = inviteObject(data['personal']);
    if (p['grantsEligible'] is bool &&
        p['fullBonusClaimed'] is bool &&
        [
          'successfulCount',
          'inviterPoints',
          'fullBonusPoints',
        ].every((k) => p[k] is int && p[k] >= 0)) {
      personal = InvitePersonal(
        p['grantsEligible'],
        p['successfulCount'],
        p['inviterPoints'],
        p['fullBonusPoints'],
        p['fullBonusClaimed'],
        claimedBonusPoints:
            p['claimedFullBonusPoints'] is int &&
                p['claimedFullBonusPoints'] >= 0
            ? p['claimedFullBonusPoints']
            : null,
      );
    }
  }
  return InviteOverview(activity, personal);
}

InviteCode inviteCode(Map<String, dynamic> data, InviteLinkPolicy policy) {
  inviteProtocolMetadata(data, policy);
  final code = inviteText(data, 'code');
  final url = inviteText(data, 'shareUrl');
  if (!matchesPublishedInviteLink(url, code)) {
    throw const InviteFailure('INVALID_CODE');
  }
  if (data['activity'] == null) {
    throw const InviteFailure('INVITE_ACTIVITY_CHANGED');
  }
  final rawActivity = inviteObject(data['activity']);
  final period = rawActivity['periodId'];
  if (period is! String || period.trim().isEmpty) {
    throw const InviteFailure('INVITE_ACTIVITY_CHANGED');
  }
  final overview = inviteOverview(data);
  return InviteCode(
    code,
    url,
    inviteText(data, 'expiresAt'),
    inviteInt(data, 'confirmedUsed'),
    inviteInt(data, 'reservedCount'),
    inviteInt(data, 'available'),
    overview,
  );
}
