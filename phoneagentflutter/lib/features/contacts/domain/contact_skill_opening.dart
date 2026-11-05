/// Current App template with the v66 production openings for older catalogs.
String contactSkillOpening(
  String skillId,
  String name,
  String fallback, {
  String? template,
}) {
  final normalized = name.trim();
  if (normalized.isEmpty) return fallback;
  final configured = template?.trim() ?? '';
  if (configured.isNotEmpty) {
    return configured.replaceAll('{contactName}', normalized);
  }
  return switch (skillId.trim()) {
    'restaurant_booking' => '想订$normalized？告诉我时间和人数就行，有其他要求也可以一起说。',
    'meeting_notification' => '要通知$normalized几点在哪开会？我来帮你打电话通知。',
    'business_event_invitation' => '要邀约什么活动？跟我说下主题、时间地点，还有以谁的名义打。',
    _ => fallback,
  };
}
