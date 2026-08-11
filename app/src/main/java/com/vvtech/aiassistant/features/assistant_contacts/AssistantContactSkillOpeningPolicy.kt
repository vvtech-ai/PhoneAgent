package com.vvtech.aiassistant.features.assistant_contacts

internal fun buildAssistantContactSkillOpening(
    skillId: String,
    contactName: String,
    fallbackOpening: String?
): String? {
    val normalizedName = contactName.trim()
    if (normalizedName.isEmpty()) return fallbackOpening

    return when (skillId.trim()) {
        "restaurant_booking" ->
            "想订${normalizedName}？告诉我时间和人数就行，有其他要求也可以一起说。"

        "meeting_notification" ->
            "要通知${normalizedName}几点在哪开会？我来帮你打电话通知。"

        "business_event_invitation" ->
            "要邀约什么活动？跟我说下主题、时间地点，还有以谁的名义打。"

        else -> fallbackOpening
    }
}
