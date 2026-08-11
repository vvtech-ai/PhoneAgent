package com.vvtech.aiassistant.features.assistant_timeline

import com.google.gson.JsonArray
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import com.vvtech.aiassistant.domain.conversation.ConversationLedgerEvent
import com.vvtech.aiassistant.domain.conversation.ConversationLedgerEventType
import com.vvtech.aiassistant.domain.conversation.StableConversationLedgerEventType

internal object InteractiveToolTimelineProjection {
    const val DISPLAY_PAYLOAD_VERSION = 1

    fun map(payload: JsonObject): ConversationTimelinePayload.AssistantMessage? {
        val toolName = payload.text("toolName")
        if (toolName !in TOOL_NAMES ||
            payload.int("displayPayloadVersion") != DISPLAY_PAYLOAD_VERSION
        ) {
            return null
        }
        val arguments = payload.objectField("arguments") ?: return null
        val text = when (toolName) {
            ASK_USER -> askUserText(arguments)
            REQUEST_PERMISSION ->
                arguments.text("reason").trim().ifBlank { "需要你授权后才能继续" }
            IMPORT_DOCUMENT ->
                arguments.text("reason").trim().ifBlank { "请上传 Markdown 或 TXT 文档" }
            else -> ""
        }
        return text.trim()
            .takeIf(String::isNotBlank)
            ?.let(ConversationTimelinePayload::AssistantMessage)
    }

    fun requiresPayloadUpgrade(event: ConversationLedgerEvent): Boolean {
        val stableType = (event.type as? ConversationLedgerEventType.Known)?.stable
        return stableType == StableConversationLedgerEventType.TOOL_REQUESTED &&
            event.payload.text("toolName") in TOOL_NAMES &&
            event.payload.int("displayPayloadVersion") != DISPLAY_PAYLOAD_VERSION
    }

    private fun askUserText(arguments: JsonObject): String {
        val title = arguments.text("title").trim().ifBlank { "再确认几件事" }
        val questions = arguments.questions()
        return buildString {
            append(title)
            questions.forEach { question ->
                append("\n· ")
                append(question)
            }
        }
    }

    private fun JsonObject.questions(): List<String> {
        val questions = arrayField("questionsJson")
            ?.mapNotNull { question ->
                question.takeIf { it.isJsonObject }
                    ?.asJsonObject
                    ?.text("prompt")
                    ?.trim()
                    ?.takeIf(String::isNotBlank)
            }
            .orEmpty()
        if (questions.isNotEmpty()) return questions
        return listOfNotNull(text("question").trim().takeIf(String::isNotBlank))
    }

    private fun JsonObject.arrayField(name: String): JsonArray? {
        val value = get(name)?.takeUnless { it.isJsonNull } ?: return null
        if (value.isJsonArray) return value.asJsonArray
        val raw = value.takeIf { it.isJsonPrimitive && it.asJsonPrimitive.isString }
            ?.asString
            ?.trim()
            ?.takeIf(String::isNotBlank)
            ?: return null
        return runCatching { JsonParser().parse(raw) }
            .getOrNull()
            ?.takeIf { it.isJsonArray }
            ?.asJsonArray
    }

    private fun JsonObject.objectField(name: String): JsonObject? =
        get(name)?.takeUnless { it.isJsonNull }?.takeIf { it.isJsonObject }?.asJsonObject

    private fun JsonObject.text(name: String): String =
        get(name)?.takeUnless { it.isJsonNull }
            ?.takeIf { it.isJsonPrimitive && it.asJsonPrimitive.isString }
            ?.asString
            .orEmpty()

    private fun JsonObject.int(name: String): Int? =
        runCatching {
            get(name)?.takeUnless { it.isJsonNull }
                ?.takeIf { it.isJsonPrimitive && it.asJsonPrimitive.isNumber }
                ?.asInt
        }.getOrNull()

    private const val ASK_USER = "askUser"
    private const val REQUEST_PERMISSION = "requestPermission"
    private const val IMPORT_DOCUMENT = "importDocument"
    private val TOOL_NAMES = setOf(ASK_USER, REQUEST_PERMISSION, IMPORT_DOCUMENT)
}
