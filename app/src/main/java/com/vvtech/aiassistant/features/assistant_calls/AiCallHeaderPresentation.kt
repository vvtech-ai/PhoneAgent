package com.vvtech.aiassistant.features.assistant_calls

import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import java.util.Locale

internal fun aiCallStatusWithDuration(callState: String?, seconds: Int): String {
    val statusText = if (isAiCallConnected(callState)) {
        currentAppText("已接通", "Connected")
    } else {
        currentAppText("接通中", "Connecting")
    }
    val safeSeconds = seconds.coerceAtLeast(0)
    return "%s %02d:%02d".format(statusText, safeSeconds / 60, safeSeconds % 60)
}

internal fun isAiCallConnected(callState: String?): Boolean =
    callState?.trim()?.uppercase(Locale.ROOT) == "CONNECTED"

internal fun aiCallDisplayNumber(value: String?): String {
    val normalized = value.orEmpty().trim()
    val digitCount = normalized.count(Char::isDigit)
    return normalized.takeIf {
        digitCount >= 3 && aiCallPhoneDisplayPattern.matches(it)
    }.orEmpty()
}

private val aiCallPhoneDisplayPattern = Regex("^[+()\\-\\s0-9]+$")
