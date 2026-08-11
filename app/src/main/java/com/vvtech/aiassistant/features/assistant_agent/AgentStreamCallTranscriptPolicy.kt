package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.AgentChatResponse
import com.vvtech.aiassistant.core.model.CallResultPayload
import com.vvtech.aiassistant.core.model.CallSpecPayload
import com.vvtech.aiassistant.features.assistant.CallPageData
import com.vvtech.aiassistant.features.assistant.TranscriptLine
import com.vvtech.aiassistant.features.assistant.TranscriptRole

internal object AgentStreamCallTranscriptPolicy {
    fun callResultPageData(
        current: CallPageData,
        response: AgentChatResponse,
        resultStatusText: String
    ): CallPageData {
        val result = response.callResult
        val includeDialogue = current.transcript.none { isStreamingDialogueLine(it) }
        val resultLines = result?.let { callResultTranscriptLines(it, includeDialogue) }.orEmpty()
        return current.copy(
            status = resultStatusText,
            callResult = result,
            transcript = mergeTranscriptPreservingOccurrences(current.transcript, resultLines)
        )
    }

    fun mergeTranscriptPreservingOccurrences(
        current: List<TranscriptLine>,
        incoming: List<TranscriptLine>
    ): List<TranscriptLine> {
        if (current.isEmpty()) return incoming
        val remainingCurrentOccurrences = current
            .groupingBy(::transcriptIdentity)
            .eachCount()
            .toMutableMap()
        val missingIncoming = incoming.filter { line ->
            val identity = transcriptIdentity(line)
            val remaining = remainingCurrentOccurrences[identity] ?: 0
            if (remaining <= 0) {
                true
            } else {
                if (remaining == 1) {
                    remainingCurrentOccurrences.remove(identity)
                } else {
                    remainingCurrentOccurrences[identity] = remaining - 1
                }
                false
            }
        }
        return current + missingIncoming
    }

    fun mergeDistinctTranscript(
        current: List<TranscriptLine>,
        incoming: List<TranscriptLine>
    ): List<TranscriptLine> {
        return incoming.fold(current) { acc, line ->
            if (acc.any { it.role == line.role && it.text == line.text }) acc else acc + line
        }
    }

    private fun transcriptIdentity(line: TranscriptLine): Pair<TranscriptRole, String> =
        line.role to line.text.trim()

    fun callSpecTranscriptNotes(spec: CallSpecPayload): List<TranscriptLine> {
        val fields = linkedMapOf<String, String>()
        fun put(label: String, value: String?) {
            val normalized = value?.trim()?.takeIf { it.isNotBlank() } ?: return
            fields[label] = normalized
        }
        val scene = resolveCallSpecSceneType(spec.scene, "")
        put(
            when (scene) {
                "FOOD_ORDERING" -> "餐厅"
                "HOTEL_BOOKING" -> "酒店"
                else -> "联系人"
            },
            spec.targetName
        )
        put("电话", spec.phoneNumber)
        put("需求", spec.primaryGoal)
        spec.summaryLines.forEach { line ->
            val index = line.indexOf('：').takeIf { it >= 0 } ?: line.indexOf(':')
            if (index <= 0 || index >= line.lastIndex) return@forEach
            val rawKey = line.substring(0, index).trim()
            val rawValue = line.substring(index + 1).trim()
            val mapped = callSpecDisplayField(rawKey, rawValue, scene) ?: return@forEach
            put(mapped.first, mapped.second)
        }
        return fields.map { (label, value) ->
            TranscriptLine(TranscriptRole.Note, "通话任务字段：$label：$value")
        }
    }

    fun resolveCallSpecSceneType(scene: String?, currentSceneType: String): String {
        return when (scene?.trim()?.lowercase()) {
            "food", "food_ordering", "restaurant", "restaurant_booking", "dining", "booking_food" -> "FOOD_ORDERING"
            "hotel", "hotel_booking", "lodging" -> "HOTEL_BOOKING"
            "flight", "flight_booking", "ticket", "air_ticket" -> "FLIGHT_BOOKING"
            "ai_call", "call", "phone", "general_call", "general",
            "message_relay", "meeting_notification", "notification" -> "AI_CALL"
            else -> currentSceneType.ifBlank { "AI_CALL" }
        }
    }

    private fun callSpecDisplayField(key: String, value: String, scene: String): Pair<String, String>? {
        val normalizedKey = key.trim()
        val normalizedValue = value.trim().takeIf { it.isNotBlank() } ?: return null
        val label = when (normalizedKey) {
            "restaurantName", "餐厅", "饭店" -> "餐厅"
            "targetName" -> when (scene) {
                "FOOD_ORDERING" -> "餐厅"
                "HOTEL_BOOKING" -> "酒店"
                else -> "联系人"
            }
            "hotelName", "酒店" -> "酒店"
            "reservationTime", "mainDate", "time", "用餐时间", "到店时间", "时间" -> "时间"
            "partySize", "guestCount", "用餐人数", "人数" -> "人数"
            "needPrivateRoom", "privateRoom", "包房", "包间" -> "包房"
            "contactName", "联系人", "预订人" -> "联系人"
            "contactPhone", "phone", "联系电话", "手机号" -> "联系电话"
            "roomType", "房型" -> "房型"
            else -> return null
        }
        val displayValue = when (normalizedKey) {
            "reservationTime", "mainDate" -> normalizedValue.replace('T', ' ')
            "partySize", "guestCount" -> {
                if (Regex("""^\d+$""").matches(normalizedValue)) "${normalizedValue}人" else normalizedValue
            }
            "needPrivateRoom", "privateRoom" -> {
                when (normalizedValue.lowercase()) {
                    "true", "yes", "1" -> "需要包房"
                    "false", "no", "0" -> "不需要包房"
                    else -> normalizedValue
                }
            }
            else -> normalizedValue
        }
        return label to displayValue
    }

    private fun callResultTranscriptLines(
        result: CallResultPayload,
        includeDialogue: Boolean
    ): List<TranscriptLine> {
        val dialogueSource = listOfNotNull(
            result.metadata?.get("dialogueTranscript"),
            result.metadata?.get("dialogueDetail"),
            result.metadata?.get("dialogue"),
            result.metadata?.get("transcript")
        ).firstOrNull { it.isNotBlank() }
        val parsedDialogue = if (includeDialogue) {
            parseCallDialogueDetail(dialogueSource ?: result.detail)
        } else {
            emptyList()
        }
        if (parsedDialogue.isNotEmpty()) {
            val summaryLine = callResultSummaryLine(result)
            return if (summaryLine == null) parsedDialogue else parsedDialogue + summaryLine
        }
        return listOfNotNull(callResultSummaryLine(result))
    }

    private fun callResultSummaryLine(result: CallResultPayload): TranscriptLine? {
        val title = if (looksLikeBookingResult(result)) "预订结果" else "AI代打结果"
        val headline = result.headline.trim()
        val detail = result.detail.trim()
        val reason = result.metadata?.get("agentReason")?.trim().orEmpty()
        val detailText = listOf(detail, reason)
            .map { it.trim() }
            .filter { it.isNotBlank() && it != headline }
            .distinct()
            .joinToString("\n")
        val text = when {
            headline.isNotBlank() && detailText.isNotBlank() -> {
                "$title：$headline\n$detailText"
            }
            detailText.isNotBlank() -> "$title：$detailText"
            headline.isNotBlank() -> "$title：$headline"
            else -> title
        }
        return text.takeIf { it.isNotBlank() }?.let { TranscriptLine(TranscriptRole.Note, it) }
    }

    private fun looksLikeBookingResult(result: CallResultPayload): Boolean {
        val source = buildString {
            append(result.headline).append('\n')
            append(result.detail).append('\n')
            result.metadata?.forEach { (key, value) ->
                append(key).append('=').append(value).append('\n')
            }
        }
        return Regex("预订|预约|预留|餐厅|酒店|机票|包间|包房|到店|用餐|入住")
            .containsMatchIn(source)
    }

    private fun parseCallDialogueDetail(detail: String): List<TranscriptLine> {
        return detail
            .lineSequence()
            .map { it.trim() }
            .filter { it.isNotBlank() }
            .mapNotNull(::parseCallDialogueLine)
            .filter { it.text.isNotBlank() }
            .toList()
    }

    private fun parseCallDialogueLine(line: String): TranscriptLine? {
        val separatorIndex = firstDialogueSeparatorIndex(line).takeIf { it > 0 } ?: return null
        val speaker = line.substring(0, separatorIndex)
            .trim()
            .removeSurrounding("[", "]")
            .removeSurrounding("【", "】")
            .lowercase()
        val text = line.substring(separatorIndex + 1).trim().takeIf { it.isNotBlank() } ?: return null
        val role = when (speaker) {
            "assistant", "ai", "a.i.", "chaken.ai", "ai助理", "助手", "智能助理", "机器人" ->
                TranscriptRole.Assistant
            "callee", "merchant", "remote", "shop", "store", "restaurant",
            "对方", "商家", "店员", "餐厅", "被叫", "接听方", "联系人", "客户" ->
                TranscriptRole.Remote
            else -> return null
        }
        return TranscriptLine(role = role, text = text)
    }

    private fun firstDialogueSeparatorIndex(line: String): Int {
        val ascii = line.indexOf(':')
        val fullWidth = line.indexOf('：')
        return listOf(ascii, fullWidth)
            .filter { it >= 0 }
            .minOrNull()
            ?: -1
    }

    private fun isStreamingDialogueLine(line: TranscriptLine): Boolean {
        return line.role == TranscriptRole.Assistant || line.role == TranscriptRole.Remote
    }
}
