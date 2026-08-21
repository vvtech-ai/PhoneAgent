package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.domain.task.ReceiptField
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText

internal fun receiptFieldDisplayRows(fields: List<ReceiptField>?): List<Pair<String, String>> =
    fields.orEmpty().mapNotNull { field ->
        if (field.label.isBlank() || field.value.isBlank()) {
            null
        } else {
            receiptFieldDisplayLabel(field) to receiptFieldDisplayValue(field)
        }
    }

internal fun receiptFieldsCopyText(
    fields: List<ReceiptField>?,
    title: String = currentAppText("任务回执", "Task Receipt"),
): String = buildList {
    add(title.ifBlank { currentAppText("任务回执", "Task Receipt") })
    receiptFieldDisplayRows(fields).forEach { (label, value) ->
        add("$label${currentAppText("：", ": ")}$value")
    }
}.joinToString("\n")

private fun receiptFieldDisplayLabel(field: ReceiptField): String {
    val raw = field.label.trim()
    return when (field.key.trim().ifBlank { raw }) {
        "任务", "task", "taskType" -> currentAppText(raw, "Task")
        "餐厅", "restaurant", "restaurantName" -> currentAppText(raw, "Restaurant")
        "人数", "用餐人数", "partySize", "guestCount" -> currentAppText(raw, "Party Size")
        "时间", "用餐时间", "reservationTime", "mainDate" -> currentAppText(raw, "Time")
        "短信", "sms", "smsConfirmation" -> currentAppText(raw, "SMS")
        "状态", "status" -> currentAppText(raw, "Status")
        "联系人", "contactName" -> currentAppText(raw, "Contact")
        "联系电话", "手机号", "contactPhone", "phone" -> currentAppText(raw, "Phone")
        "包房", "包间", "privateRoom", "needPrivateRoom" -> currentAppText(raw, "Private Room")
        else -> currentAppText(raw, sanitizeUserFacingNetworkText(raw, VoiceLanguage.English))
    }
}

private fun receiptFieldDisplayValue(field: ReceiptField): String {
    val raw = field.value.trim()
    if (raw.isBlank()) return ""
    val key = field.key.trim().ifBlank { field.label.trim() }
    val english = when {
        key in setOf("partySize", "guestCount", "人数", "用餐人数") -> {
            Regex("""^(\d+)\s*(?:人|people)?$""").matchEntire(raw)?.let { match ->
                "${match.groupValues[1]} people"
            } ?: sanitizeUserFacingNetworkText(raw, VoiceLanguage.English)
        }
        key in setOf("reservationTime", "mainDate", "时间", "用餐时间") -> {
            sanitizeUserFacingNetworkText(raw.replace('T', ' '), VoiceLanguage.English)
        }
        raw == "餐厅预订" -> "Restaurant Booking"
        raw == "任务完成" -> "Task Complete"
        raw.contains("无需短信确认") -> "No SMS confirmation needed"
        raw.contains("商家表示无需短信确认") -> "The merchant said no SMS confirmation is needed"
        raw.equals("true", ignoreCase = true) -> "Yes"
        raw.equals("false", ignoreCase = true) -> "No"
        else -> sanitizeUserFacingNetworkText(raw, VoiceLanguage.English)
    }
    return currentAppText(raw, english)
}
