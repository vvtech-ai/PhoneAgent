import 'invite.dart';

class InviteEntryPresentation {
  const InviteEntryPresentation(this.visible, this.subtitle);
  factory InviteEntryPresentation.fromOverview(InviteOverview? overview) {
    final activity = overview?.activity;
    final personal = overview?.personal;
    final equal =
        personal?.eligible == true &&
        personal!.inviterPoints > 0 &&
        personal.inviterPoints == activity?.inviteePoints;
    return InviteEntryPresentation(
      activity != null,
      equal
          ? '邀请好友注册 Phone Agent，双方各得 ${personal.inviterPoints} 积分'
          : '邀请好友注册 Phone Agent，邀请奖励以活动规则为准',
    );
  }
  final bool visible;
  final String subtitle;
}

String inviteRecordTime(String raw) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null || !RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(raw)) {
    return raw;
  }
  final time = parsed.toUtc().add(const Duration(hours: 8));
  String two(int n) => n.toString().padLeft(2, '0');
  return '${time.month}/${time.day} ${two(time.hour)}:${two(time.minute)}';
}
