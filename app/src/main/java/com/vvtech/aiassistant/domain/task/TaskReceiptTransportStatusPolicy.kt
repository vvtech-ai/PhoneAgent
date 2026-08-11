package com.vvtech.aiassistant.domain.task

import java.util.Locale

/** Mirrors the backend Agent semantic-outcome to CallResult transport-status contract. */
object TaskReceiptTransportStatusPolicy {
    fun normalize(raw: String?): String = when (raw?.trim()?.uppercase(Locale.ROOT)) {
        "SUCCESS", "COMPLETED" -> "COMPLETED"
        "USER_CANCELLED", "CANCELLED" -> "CANCELLED"
        "UNCLEAR" -> "UNCLEAR"
        "FAILED", "NEEDS_RECALL" -> "FAILED"
        else -> "FAILED"
    }
}
