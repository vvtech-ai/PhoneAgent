package com.vvtech.aiassistant.domain.task

/** Server-validated, user-visible field from a committed task receipt. */
data class ReceiptField(
    val key: String,
    val label: String,
    val value: String,
)
