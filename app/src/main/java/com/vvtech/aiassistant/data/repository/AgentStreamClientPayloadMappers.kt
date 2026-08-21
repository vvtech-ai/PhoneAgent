package com.vvtech.aiassistant.data.repository

import com.google.gson.Gson
import com.vvtech.aiassistant.core.model.CallResultPayload
import com.vvtech.aiassistant.core.model.CallSpecPayload
import com.vvtech.aiassistant.core.model.DocumentImportRequestPayload
import com.vvtech.aiassistant.core.model.PermissionRequestPayload
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import java.util.Locale

internal fun agentPermissionRequestFromClientData(data: Map<String, Any?>): PermissionRequestPayload {
    val nested = agentClientDataMap(data["permissionRequest"]).ifEmpty { data }
    return PermissionRequestPayload(
        permissionKey = nested["permissionKey"]?.toString().orEmpty(),
        androidPermission = nested["androidPermission"]?.toString()?.takeIf { it.isNotBlank() },
        reason = nested["reason"]?.toString()?.takeIf { it.isNotBlank() },
        statusBeforeRequest = nested["statusBeforeRequest"]?.toString()?.takeIf { it.isNotBlank() }
    )
}

internal fun agentDocumentImportRequestFromClientData(data: Map<String, Any?>): DocumentImportRequestPayload {
    val nested = agentClientDataMap(data["documentImportRequest"]).ifEmpty { data }
    return DocumentImportRequestPayload(
        title = nested["title"]?.toString()?.takeIf { it.isNotBlank() },
        reason = nested["reason"]?.toString()?.takeIf { it.isNotBlank() },
        acceptedTypes = agentClientStringList(nested["acceptedTypes"]).takeIf { it.isNotEmpty() },
        acceptedMimeTypes = agentClientStringList(nested["acceptedMimeTypes"]).takeIf { it.isNotEmpty() },
        maxBytes = agentClientLong(nested["maxBytes"])
    )
}

internal fun agentCallSpecFromClientData(data: Map<String, Any?>): CallSpecPayload {
    return CallSpecPayload(
        phoneNumber = data["phoneNumber"]?.toString().orEmpty(),
        scene = data["scene"]?.toString().orEmpty(),
        targetName = data["targetName"]?.toString().orEmpty(),
        primaryGoal = data["primaryGoal"]?.toString().orEmpty(),
        summaryLines = (data["summaryLines"] as? List<*>)
            ?.mapNotNull { it?.toString() }
            .orEmpty(),
        negotiationRules = agentClientStringList(data["negotiationRules"]).takeIf { it.isNotEmpty() },
        boundaries = agentClientStringList(data["boundaries"]).takeIf { it.isNotEmpty() }
    )
}

internal fun agentClientDataMap(value: Any?): Map<String, Any?> {
    @Suppress("UNCHECKED_CAST")
    return value as? Map<String, Any?> ?: emptyMap()
}

internal fun agentClientStringList(value: Any?): List<String> {
    return when (value) {
        is List<*> -> value.mapNotNull { it?.toString()?.takeIf { item -> item.isNotBlank() } }
        is String -> value.split(",").mapNotNull { it.trim().takeIf { item -> item.isNotBlank() } }
        else -> emptyList()
    }
}

internal fun agentClientLong(value: Any?): Long? {
    return when (value) {
        is Number -> value.toLong()
        is String -> value.toLongOrNull() ?: value.toDoubleOrNull()?.toLong()
        else -> null
    }
}

internal fun agentClientBoolean(value: Any?): Boolean {
    return when (value) {
        is Boolean -> value
        is String -> value.equals("true", ignoreCase = true)
        is Number -> value.toInt() != 0
        else -> false
    }
}

internal fun <T> agentFromJsonValue(gson: Gson, value: Any?, clazz: Class<T>): T? {
    if (value == null) return null
    return runCatching { gson.fromJson(gson.toJson(value), clazz) }.getOrNull()
}

internal fun agentConditionsToBody(value: Any?): String {
    val items = value as? List<*> ?: return ""
    return items.mapNotNull { item ->
        val map = item as? Map<*, *> ?: return@mapNotNull null
        val label = map["label"]?.toString()?.takeIf { it.isNotBlank() } ?: return@mapNotNull null
        val rawValue = map["value"] ?: return@mapNotNull null
        val rendered = when (rawValue) {
            is Number, is Boolean -> rawValue.toString()
            else -> rawValue.toString().takeIf { it.isNotBlank() }?.let { "\"$it\"" }
        } ?: return@mapNotNull null
        "$label: $rendered"
    }.joinToString("\n")
}

internal fun agentCallResultDisplayText(displayMessage: String, callResult: CallResultPayload?): String {
    return displayMessage.ifBlank { agentCallResultBaseDisplayText(callResult) }
}

internal fun agentCallResultReportedOutcome(metadata: Map<String, String>?): String {
    if (metadata.isNullOrEmpty()) return ""
    val keys = listOf("agentOutcome", "reportCallOutcome", "callOutcome", "outcome", "agent_outcome")
    return keys
        .asSequence()
        .mapNotNull { key -> metadata[key]?.trim()?.takeIf { it.isNotBlank() } }
        .firstOrNull()
        ?.uppercase(Locale.ROOT)
        .orEmpty()
}

private fun agentCallResultBaseDisplayText(callResult: CallResultPayload?): String {
    if (callResult == null) return currentAppText("任务已完成", "Task completed")
    val source = agentCallResultSource(callResult)
    when (agentCallResultReportedOutcome(callResult.metadata)) {
        "SUCCESS", "UNCLEAR" -> return currentAppText("任务已完成", "Task completed")
        "USER_CANCELLED", "USER_CANCELED" -> return currentAppText("通话已取消", "Call canceled")
        "FAILED", "NEEDS_RECALL" -> return currentAppText("任务未完成", "Task incomplete")
    }
    val status = callResult.status.trim().uppercase(Locale.ROOT)
    val resultCode = callResult.metadata?.get("resultCode")?.trim()?.uppercase(Locale.ROOT).orEmpty()
    return when {
        status in setOf("CANCELLED", "CANCELED", "USER_CANCELLED", "USER_CANCELED", "USER_INTERRUPTED") ||
            resultCode in setOf("CANCELLED", "CANCELED", "USER_CANCELLED", "USER_CANCELED", "CALL_CANCELLED", "CALL_CANCELED") ||
            Regex("取消|已取消|挂断|已挂断|中止|手动中止|用户在\\s*App\\s*端").containsMatchIn(source) ->
                currentAppText("通话已取消", "Call canceled")

        status in setOf("FAILED", "ERROR", "FAIL") ||
            resultCode.startsWith("FAILED") ||
            resultCode in setOf(
                "CALL_FAILED",
                "CALL_INTERRUPTED",
                "NO_EFFECTIVE_DIALOGUE",
                "NO_ANSWER",
                "BUSY",
                "REJECTED",
                "TIMEOUT",
                "MERCHANT_REQUESTED_CALLBACK",
                "INCOMPLETE_OR_UNCLEAR"
            ) ||
            Regex("失败|未完成|未接通|未形成有效通话|预订未成功|预约未成功|未订到|没订到|没有订到|结果不明确")
                .containsMatchIn(source) -> currentAppText("任务未完成", "Task incomplete")

        else -> currentAppText("任务已完成", "Task completed")
    }
}

private fun agentCallResultSource(callResult: CallResultPayload): String = buildString {
    append(callResult.status).append('\n')
    append(callResult.headline).append('\n')
    append(callResult.detail).append('\n')
    callResult.metadata?.forEach { (key, value) ->
        append(key).append('=').append(value).append('\n')
    }
}
