package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.features.assistant.VoiceLanguage

internal fun VoiceLanguage.agentResponseLanguageName(): String = when (this) {
    VoiceLanguage.English -> "English"
    VoiceLanguage.Japanese -> "Japanese"
    VoiceLanguage.Chinese -> "Simplified Chinese"
}

internal fun agentBackendMessageForLanguage(
    message: String,
    languageCode: String
): String {
    val trimmed = message.trim()
    if (trimmed.isBlank()) return message

    return when (VoiceLanguage.fromCode(languageCode)) {
        VoiceLanguage.English -> """
            Language instruction for this PhoneAgent English demo:
            Understand the user's request even if it includes Chinese names, addresses, or local business data.
            Reply in English only. Keep assistant messages, tool titles, option titles, status text, and spoken text in English.
            If you need to place an outbound call, the phone conversation with the callee must also be in English only.
            Do not switch to Chinese because the restaurant, address, contact, or callee is Chinese.
            When creating a makeCall callSpec, write targetName, primaryGoal, openingText, summaryLines, negotiationRules, boundaries, and successCriteria in English.
            Add an explicit call boundary that says: Speak to the callee in English only.
            Translate task labels, option titles, status text, call summaries, receipts, and spoken scripts into English.
            Preserve phone numbers and addresses as-is. Render Chinese business or contact names with an English alias or concise English description when possible; do not output pinyin-style fake English for statuses, scripts, summaries, or labels.

            User request:
            $trimmed
        """.trimIndent()
        else -> message
    }
}
