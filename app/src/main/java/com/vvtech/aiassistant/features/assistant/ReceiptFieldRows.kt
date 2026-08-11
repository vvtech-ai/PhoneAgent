package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.domain.task.ReceiptField

internal fun receiptFieldDisplayRows(fields: List<ReceiptField>?): List<Pair<String, String>> =
    fields.orEmpty().mapNotNull { field ->
        if (field.label.isBlank() || field.value.isBlank()) {
            null
        } else {
            field.label to field.value
        }
    }

internal fun receiptFieldsCopyText(
    fields: List<ReceiptField>?,
    title: String = "任务回执",
): String = buildList {
    add(title.ifBlank { "任务回执" })
    receiptFieldDisplayRows(fields).forEach { (label, value) ->
        add("$label：$value")
    }
}.joinToString("\n")
