import 'home_config.dart';

// Card snapshot: v66 a0bedb12 HomeConfigDefaults. Openings are copied verbatim
// from the same revision's backend/src/main/resources/skills frontmatter:
// restaurant-booking, meeting-notification, event-invitation,
// sales-recommendation and meeting-notification-v2. Apology uses Consent.
const builtinHome = HomeConfig(
  'builtin-1',
  [
    HomeSlogan('primary', '给我一个任务', '我来帮你打电话'),
    HomeSlogan('secondary', '老大，请吩咐', '我来帮你打电话'),
  ],
  [
    HomeCard(
      id: 'restaurant_booking',
      title: '订餐厅',
      subtitle: '帮你询位、预订包房',
      status: HomeCardStatus.enabled,
      action: HomeAction.skill,
      skillId: 'restaurant_booking',
      opening: '想订哪家餐厅？告诉我时间和人数就行，有其他要求也可以一起说。',
    ),
    HomeCard(
      id: 'meeting_invite',
      title: '会议邀请',
      subtitle: '批量通知参会、确认回执',
      status: HomeCardStatus.enabled,
      action: HomeAction.skill,
      skillId: 'meeting_notification',
      opening: '要通知谁、几点在哪开会？我来帮你打电话通知。',
    ),
    HomeCard(
      id: 'apology',
      title: '道歉',
      subtitle: '代你表达歉意',
      status: HomeCardStatus.comingSoon,
      action: HomeAction.skill,
      skillId: 'apology_master',
    ),
    HomeCard(
      id: 'event_invite',
      title: '活动邀约',
      subtitle: '批量邀约、确认参加',
      status: HomeCardStatus.enabled,
      action: HomeAction.skill,
      skillId: 'business_event_invitation',
      opening: '请告诉我或上传活动内容、受邀联系人名单及相关资料。我来打电话邀请。',
    ),
    HomeCard(
      id: 'move_car',
      title: '挪车',
      subtitle: '联系车主协调挪车',
      status: HomeCardStatus.comingSoon,
      action: HomeAction.none,
    ),
    HomeCard(
      id: 'sales_promotion',
      title: '销售推荐',
      subtitle: '批量介绍、确认兴趣',
      status: HomeCardStatus.enabled,
      action: HomeAction.skill,
      skillId: 'sales_recommendation',
      opening: '请告诉我或上传推广信息、联系人相关资料。我来打电话联系。',
    ),
    HomeCard(
      id: 'simultaneous_interpretation',
      title: '同声传译',
      subtitle: '实时翻译通话。',
      status: HomeCardStatus.comingSoon,
      action: HomeAction.translation,
      skillId: 'simultaneous_interpretation',
    ),
    HomeCard(
      id: 'meeting_invite_v2',
      title: '大型会议邀请',
      subtitle: '导入资料、批量邀请',
      status: HomeCardStatus.enabled,
      action: HomeAction.skill,
      skillId: 'meeting_notification_v2',
      opening: '请告诉我或上传会议通知、受邀联系人名单及相关资料。我来打电话邀请。',
    ),
  ],
  builtin: true,
);
