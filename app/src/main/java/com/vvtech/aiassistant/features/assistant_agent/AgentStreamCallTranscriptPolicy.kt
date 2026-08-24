package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.AgentChatResponse
import com.vvtech.aiassistant.core.model.CallResultPayload
import com.vvtech.aiassistant.core.model.CallSpecPayload
import com.vvtech.aiassistant.features.assistant.CallPageData
import com.vvtech.aiassistant.features.assistant.TranscriptLine
import com.vvtech.aiassistant.features.assistant.TranscriptRole
import com.vvtech.aiassistant.features.assistant.VoiceLanguage
import com.vvtech.aiassistant.features.assistant.sanitizeUserFacingNetworkText
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText

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
                "FOOD_ORDERING" -> currentAppText("餐厅", "Restaurant")
                "HOTEL_BOOKING" -> currentAppText("酒店", "Hotel")
                else -> currentAppText("联系人", "Contact")
            },
            spec.targetName
        )
        put(currentAppText("电话", "Phone"), spec.phoneNumber)
        put(currentAppText("需求", "Request"), spec.primaryGoal)
        spec.summaryLines.forEach { line ->
            val index = line.indexOf('：').takeIf { it >= 0 } ?: line.indexOf(':')
            if (index <= 0 || index >= line.lastIndex) return@forEach
            val rawKey = line.substring(0, index).trim()
            val rawValue = line.substring(index + 1).trim()
            val mapped = callSpecDisplayField(rawKey, rawValue, scene) ?: return@forEach
            put(mapped.first, mapped.second)
        }
        return fields.map { (label, value) ->
            TranscriptLine(
                TranscriptRole.Note,
                currentAppText("通话任务字段：$label：$value", "Call task field: $label: $value")
            )
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
            "restaurantName", "餐厅", "饭店" -> currentAppText("餐厅", "Restaurant")
            "targetName" -> when (scene) {
                "FOOD_ORDERING" -> currentAppText("餐厅", "Restaurant")
                "HOTEL_BOOKING" -> currentAppText("酒店", "Hotel")
                else -> currentAppText("联系人", "Contact")
            }
            "hotelName", "酒店" -> currentAppText("酒店", "Hotel")
            "reservationTime", "mainDate", "time", "用餐时间", "到店时间", "时间" -> currentAppText("时间", "Time")
            "partySize", "guestCount", "用餐人数", "人数" -> currentAppText("人数", "Party Size")
            "needPrivateRoom", "privateRoom", "包房", "包间" -> currentAppText("包房", "Private Room")
            "contactName", "联系人", "预订人" -> currentAppText("联系人", "Contact")
            "contactPhone", "phone", "联系电话", "手机号" -> currentAppText("联系电话", "Phone")
            "roomType", "房型" -> currentAppText("房型", "Room Type")
            else -> return null
        }
        val displayValue = when (normalizedKey) {
            "reservationTime", "mainDate" -> normalizedValue.replace('T', ' ')
            "partySize", "guestCount" -> {
                if (Regex("""^\d+$""").matches(normalizedValue)) {
                    currentAppText("${normalizedValue}人", "$normalizedValue people")
                } else {
                    normalizedValue
                }
            }
            "needPrivateRoom", "privateRoom" -> {
                when (normalizedValue.lowercase()) {
                    "true", "yes", "1" -> currentAppText("需要包房", "Private room needed")
                    "false", "no", "0" -> currentAppText("不需要包房", "No private room needed")
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
        val title = if (looksLikeBookingResult(result)) {
            currentAppText("预订结果", "Reservation Result")
        } else {
            currentAppText("AI代打结果", "AI Call Result")
        }
        val headline = englishCallDisplayText(result.headline)
        val detail = englishCallDisplayText(result.detail)
        val reason = englishCallDisplayText(result.metadata?.get("agentReason")).trim()
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
        return text.takeIf { it.isNotBlank() }?.let {
            TranscriptLine(TranscriptRole.Note, currentAppText(it, englishCallDisplayText(it)))
        }
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
        return TranscriptLine(role = role, text = currentAppText(text, englishCallDisplayText(text)))
    }

    private fun englishCallDisplayText(raw: String?): String =
        sanitizeUserFacingNetworkText(raw, VoiceLanguage.English)

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
