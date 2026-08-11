package com.vvtech.aiassistant.features.assistant_timeline

import com.google.gson.JsonObject

internal object OcrImageTimelineProjection {
    fun map(payload: JsonObject): ConversationTimelinePayload.OcrImage? {
        val attachmentId = payload.text("attachmentId") ?: return null
        val contentPath = payload.text("contentPath") ?: return null
        val contentType = payload.text("contentType") ?: return null
        val fileSize = payload.long("fileSize")?.takeIf { it > 0L } ?: return null
        val anchorStepCount = payload.int("anchorStepCount")?.takeIf { it >= 0 } ?: return null
        val createdOrdinal = payload.long("createdOrdinal")?.takeIf { it >= 0L } ?: return null
        val fullText = payload.text("fullText") ?: return null
        val fields = payload.getAsJsonArray("fields")?.mapNotNull { element ->
            val field = element.takeIf { it.isJsonObject }?.asJsonObject ?: return@mapNotNull null
            val label = field.text("label") ?: return@mapNotNull null
            val value = field.text("value") ?: return@mapNotNull null
            ConversationTimelinePayload.OcrField(label, value)
        } ?: emptyList()
        val segments = payload.getAsJsonArray("segments")?.mapNotNull { element ->
            element.takeIf { it.isJsonPrimitive }?.asString?.takeIf(String::isNotBlank)
        } ?: emptyList()
        return ConversationTimelinePayload.OcrImage(
            attachmentId = attachmentId,
            contentPath = contentPath,
            contentType = contentType,
            fileSize = fileSize,
            anchorStepCount = anchorStepCount,
            createdOrdinal = createdOrdinal,
            fields = fields,
            segments = segments,
            fullText = fullText,
        )
    }

    private fun JsonObject.text(name: String): String? =
        get(name)?.takeIf { it.isJsonPrimitive }?.asString?.trim()?.takeIf(String::isNotBlank)

    private fun JsonObject.long(name: String): Long? =
        runCatching { get(name)?.asLong }.getOrNull()

    private fun JsonObject.int(name: String): Int? =
        runCatching { get(name)?.asInt }.getOrNull()
}
