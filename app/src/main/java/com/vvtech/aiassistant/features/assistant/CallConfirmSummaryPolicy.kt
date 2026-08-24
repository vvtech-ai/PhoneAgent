package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.features.assistant_i18n.currentAppText

private val internalCallConfirmFactKeys = setOf(
    "targetname",
    "phonenumber",
    "contactname",
    "resolvedname",
    "requestedname",
    "contactmatchtype",
    "matchtype",
    "contactid",
    "originaltargetname"
)

internal fun visibleCallConfirmSummaryRows(summaryLines: List<String>): List<Pair<String, String>> {
    return summaryLines.mapNotNull(::parseCallConfirmSummaryLine)
        .filterNot { (label, _) -> label.lowercase() in internalCallConfirmFactKeys }
        .distinct()
}

private fun parseCallConfirmSummaryLine(line: String): Pair<String, String>? {
    val normalized = line.trim()
    if (normalized.isBlank()) return null
    val separator = listOf(normalized.indexOf('：'), normalized.indexOf(':'))
        .filter { it > 0 }
        .minOrNull()
        ?: return currentAppText("信息", "Info") to normalized
    val label = normalized.substring(0, separator).trim()
    val value = normalized.substring(separator + 1).trim()
    return (label to value).takeIf { label.isNotBlank() && value.isNotBlank() }
}
