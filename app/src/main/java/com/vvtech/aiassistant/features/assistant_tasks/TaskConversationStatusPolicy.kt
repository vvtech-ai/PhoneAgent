package com.vvtech.aiassistant.features.assistant_tasks

internal fun normalizeConversationTaskStatus(
    rawStatus: String,
    detailStatus: String? = null,
): String {
    val detailCanonical = canonicalConversationTaskStatus(detailStatus.orEmpty())
    val rawCanonical = canonicalConversationTaskStatus(rawStatus)
    if (detailCanonical in setOf("NETWORK_ERROR", "EXECUTION_ERROR")) {
        return detailCanonical
    }
    if (rawCanonical in setOf("NETWORK_ERROR", "EXECUTION_ERROR")) {
        return rawCanonical
    }

    if (conversationStatusIsTerminal(detailCanonical)) {
        return detailCanonical
    }

    if (conversationStatusIsTerminal(rawCanonical)) {
        return rawCanonical
    }

    return when {
        conversationStatusIsPendingWithoutTerminalResult(detailCanonical) -> "RUNNING"
        conversationStatusIsPendingWithoutTerminalResult(rawCanonical) -> "RUNNING"
        rawCanonical.isNotBlank() -> rawCanonical
        rawStatus.isNotBlank() -> rawStatus
        else -> "RUNNING"
    }
}
