package com.vvtech.aiassistant.features.assistant_timeline

import com.google.gson.JsonArray
import com.google.gson.JsonElement
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import com.vvtech.aiassistant.core.model.OptionItem
import com.vvtech.aiassistant.core.model.OptionsPayload
import com.vvtech.aiassistant.domain.conversation.ConversationLedgerEvent
import com.vvtech.aiassistant.domain.conversation.ConversationLedgerEventType
import com.vvtech.aiassistant.domain.conversation.StableConversationLedgerEventType

internal object ShowOptionsTimelineProjection {
    const val DISPLAY_PAYLOAD_VERSION = 1

    fun map(payload: JsonObject): ConversationTimelinePayload.AssistantMessage? {
        if (payload.text("toolName") != TOOL_NAME ||
            payload.int("displayPayloadVersion") != DISPLAY_PAYLOAD_VERSION
        ) {
            return null
        }
        val arguments = payload.objectField("arguments") ?: return null
        val options = OptionsPayload(
            title = arguments.text("title").ifBlank { "请选择" },
            items = arguments.optionsArray()
                ?.mapIndexedNotNull(::optionItem)
                .orEmpty(),
        )
        if (options.items.isEmpty()) return null
        return ConversationTimelinePayload.AssistantMessage(
            ShowOptionsDisplayTextFormatter.format(options)
        )
    }

    fun requiresPayloadUpgrade(event: ConversationLedgerEvent): Boolean {
        val stableType = (event.type as? ConversationLedgerEventType.Known)?.stable
        return stableType == StableConversationLedgerEventType.TOOL_REQUESTED &&
            event.payload.text("toolName") == TOOL_NAME &&
            event.payload.int("displayPayloadVersion") != DISPLAY_PAYLOAD_VERSION
    }

    private fun optionItem(index: Int, element: JsonElement): OptionItem? {
        val item = element.takeIf { it.isJsonObject }?.asJsonObject ?: return null
        val label = item.text("label").takeIf(String::isNotBlank) ?: return null
        return OptionItem(
            id = item.text("id").ifBlank { "option-${index + 1}" },
            label = label,
            detail = item.optionalText("detail"),
            tags = item.stringList("tags").takeIf(List<String>::isNotEmpty),
            phone = item.optionalText("phone"),
            address = item.optionalText("address"),
            distanceMeters = item.intOrNull("distanceMeters"),
        )
    }

    private fun JsonObject.optionsArray(): JsonArray? {
        val value = get("optionsJson")?.takeUnless { it.isJsonNull } ?: return null
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

    private fun JsonObject.optionalText(name: String): String? =
        text(name).trim().takeIf(String::isNotBlank)

    private fun JsonObject.stringList(name: String): List<String> =
        get(name)?.takeUnless { it.isJsonNull }
            ?.takeIf { it.isJsonArray }
            ?.asJsonArray
            ?.mapNotNull { value ->
                value.takeIf { it.isJsonPrimitive && it.asJsonPrimitive.isString }
                    ?.asString
                    ?.trim()
                    ?.takeIf(String::isNotBlank)
            }
            .orEmpty()

    private fun JsonObject.int(name: String): Int? = intOrNull(name)

    private fun JsonObject.intOrNull(name: String): Int? =
        runCatching {
            get(name)?.takeUnless { it.isJsonNull }
                ?.takeIf { it.isJsonPrimitive && it.asJsonPrimitive.isNumber }
                ?.asInt
        }.getOrNull()

    private const val TOOL_NAME = "showOptions"
}

internal object ShowOptionsDisplayTextFormatter {
    fun format(options: OptionsPayload): String = buildString {
        appendLine(options.title.ifBlank { "请选择" })
        options.items.forEachIndexed { index, item ->
            append("${index + 1}. ${item.label}")
            item.displayDetailText().takeIf(String::isNotBlank)?.let { append(" ($it)") }
            appendLine()
        }
    }.trimEnd()

    private fun OptionItem.displayDetailText(): String = listOfNotNull(
        detail?.trim()?.takeIf(String::isNotBlank),
        phone?.trim()?.takeIf(String::isNotBlank),
        address?.trim()?.takeIf(String::isNotBlank),
        distanceMeters?.let(::formatDistance),
    ).distinct().joinToString(" | ")

    private fun formatDistance(distanceMeters: Int): String =
        if (distanceMeters >= 1000) {
            "%.1fkm".format(distanceMeters / 1000.0)
        } else {
            "${distanceMeters}m"
        }
}
