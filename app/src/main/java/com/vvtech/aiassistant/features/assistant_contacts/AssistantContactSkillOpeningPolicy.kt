package com.vvtech.aiassistant.features.assistant_contacts

import com.vvtech.aiassistant.features.assistant_i18n.currentAppText

internal fun buildAssistantContactSkillOpening(
    skillId: String,
    contactName: String,
    fallbackOpening: String?
): String? {
    val normalizedName = contactName.trim()
    if (normalizedName.isEmpty()) return fallbackOpening

    return when (skillId.trim()) {
        "restaurant_booking" ->
            currentAppText(
                "想订${normalizedName}？告诉我时间和人数就行，有其他要求也可以一起说。",
                "Want to book ${normalizedName}? Tell me the time and party size. You can add any other requirements too."
            )

        "meeting_notification" ->
            currentAppText(
                "要通知${normalizedName}几点在哪开会？我来帮你打电话通知。",
                "What time and where should I notify ${normalizedName} about the meeting? I can call them for you."
            )

        "business_event_invitation" ->
            currentAppText(
                "要邀约什么活动？跟我说下主题、时间地点，还有以谁的名义打。",
                "What event are you inviting them to? Tell me the topic, time, location, and whose name to call under."
            )

        else -> fallbackOpening
    }
}
