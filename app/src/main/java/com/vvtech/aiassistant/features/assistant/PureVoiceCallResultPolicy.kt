package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.features.assistant_tasks.callDisplayBookingTargetLabel
import com.vvtech.aiassistant.features.assistant_tasks.callPageResultStatusFromSource
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText

internal fun pureVoiceContactCallRows(summary: SummaryData?, data: CallPageData): List<Pair<String, String>> {
    val rows = linkedMapOf<String, String>()
    val contact = summary?.target?.takeIf { it.isNotBlank() }
        ?: pureVoiceMeaningfulCallTarget(data.name)
        ?: pureVoiceExtractTaskField(data.transcript, "联系人")
        ?: pureVoiceExtractTaskField(data.transcript, "目标")
    val time = summary?.time?.takeIf { it.isNotBlank() && it != "待确认" }
        ?: pureVoiceExtractTaskField(data.transcript, "时间")
    val purpose = summary?.extra?.takeIf { it.isNotBlank() && it != "待确认" }
        ?: summary?.detailValue?.takeIf { it.isNotBlank() }
        ?: pureVoiceExtractTaskField(data.transcript, "目的")
        ?: pureVoiceExtractTaskField(data.transcript, "需求")
        ?: pureVoiceExtractTaskField(data.transcript, "通话事项")
        ?: pureVoiceMeaningfulCallPurpose(data.sub)
    if (!contact.isNullOrBlank()) rows["联系人"] = contact
    if (!time.isNullOrBlank()) rows["时间"] = time
    if (!purpose.isNullOrBlank()) rows["目的"] = purpose
    return rows.entries.map { pureVoiceDisplayResultRow(it.key, it.value) }.take(3)
}

private fun pureVoiceExtractTaskField(transcript: List<TranscriptLine>, label: String): String? {
    val pattern = Regex("(?:通话任务字段[:：])?\\s*${Regex.escape(label)}[:：]\\s*([^。；;\\n]+)")
    return transcript.asReversed()
        .asSequence()
        .mapNotNull { line -> pattern.find(line.text)?.groupValues?.getOrNull(1)?.trim() }
        .firstOrNull { it.isNotBlank() }
}

internal fun pureVoiceCallResultStatus(sceneType: String?, data: CallPageData): String {
    val detailSource = data.transcript.joinToString("\n") { it.text }
    return callPageResultStatusFromSource(data.status, detailSource, sceneType)
}

internal fun pureVoiceCallResultPending(status: String): Boolean {
    val normalized = status.trim()
    return normalized.contains("正在确认通话结果") ||
        normalized.contains("通话结果确认中") ||
        normalized.contains("确认通话结果")
}

internal fun pureVoiceCallResultFailed(status: String): Boolean {
    val normalized = status.trim()
    val upper = normalized.uppercase()
    return upper.contains("FAILED") ||
        upper.contains("EXECUTION_ERROR") ||
        upper.contains("CANCEL") ||
        normalized.contains("执行异常") ||
        normalized.contains("未完成") ||
        normalized.contains("失败") ||
        normalized.contains("取消")
}

internal fun pureVoiceCallResultPartial(@Suppress("UNUSED_PARAMETER") status: String): Boolean {
    // UNCLEAR/部分完成 统一按完成展示，不再单列"部分完成"态
    return false
}

private fun pureVoiceCallResultDetail(data: CallPageData): String? {
    val resultNote = data.transcript.lastOrNull {
        it.role == TranscriptRole.Note && pureVoiceLooksLikeCallResultSummaryLine(it.text)
    }?.text
    val visibleLines = data.transcript.filter {
        it.role != TranscriptRole.Note && !pureVoiceLooksLikeCallResultSummaryLine(it.text)
    }
    return resultNote
        ?: visibleLines
            .lastOrNull { line ->
                Regex("预订|预约|预留|确认|登记|大厅|包间|包房|低消|成功").containsMatchIn(line.text)
            }
            ?.text
        ?: visibleLines.lastOrNull {
            it.text.contains("预订结果") || it.text.contains("AI代打结果")
        }?.text
        ?: visibleLines.lastOrNull { it.role == TranscriptRole.Remote }?.text
        ?: visibleLines.lastOrNull { it.role == TranscriptRole.Assistant }?.text
}

internal fun pureVoiceCallResultSource(summary: SummaryData?, data: CallPageData): String {
    return buildString {
        append(data.status).append('\n')
        append(data.name).append('\n')
        append(data.sub).append('\n')
        append(data.transcript.joinToString("\n") { it.text }).append('\n')
        if (summary != null) {
            append(summary.task).append('\n')
            append(summary.target).append('\n')
            append(summary.time).append('\n')
            append(summary.extra).append('\n')
            append(summary.detailValue.orEmpty()).append('\n')
            append(summary.contactValue.orEmpty()).append('\n')
        }
    }
}

internal fun pureVoiceBookingRows(
    sceneType: String?,
    summary: SummaryData?,
    data: CallPageData
): List<Pair<String, String>> {
    val source = pureVoiceCallResultSource(summary, data)
    val rows = linkedMapOf<String, String>()
    val targetLabel = callDisplayBookingTargetLabel(sceneType, source)
    val target = summary?.target?.takeIf { it.isNotBlank() }
        ?: pureVoiceMeaningfulCallTarget(data.name)
    target?.let { rows[targetLabel] = it }

    pureVoiceExtractResultFields(source).forEach { (label, value) ->
        if (value.isNotBlank()) rows[label] = value
    }
    pureVoiceExtractTranscriptBookingFields(data.transcript).forEach { (label, value) ->
        if (value.isNotBlank()) rows[label] = value
    }

    summary?.time
        ?.takeIf { it.isNotBlank() && it != "待确认" && rows["时间"].isNullOrBlank() }
        ?.let { rows[summary.timeLabel.ifBlank { "时间" }] = it }
    summary?.extra
        ?.takeIf { it.isNotBlank() && it != "待确认" }
        ?.let { rows[summary.extraLabel.ifBlank { if (targetLabel == "酒店") "房型" else "人数" }] = it }
    summary?.detailValue
        ?.takeIf { it.isNotBlank() }
        ?.let { rows[summary.detailLabel ?: "补充"] = it }
    summary?.contactValue
        ?.takeIf { it.isNotBlank() }
        ?.let { rows[summary.contactLabel ?: "联系人"] = it }

    val contactName = rows["联系人"]?.trim().orEmpty()
    val contactPhone = rows.remove("联系电话")?.trim().orEmpty()
    if (contactName.isNotBlank() && contactPhone.isNotBlank() && !contactName.contains(contactPhone)) {
        rows["联系人"] = "$contactName，$contactPhone"
    } else if (contactName.isBlank() && contactPhone.isNotBlank()) {
        rows["联系人"] = contactPhone
    }

    return rows.entries.map { pureVoiceDisplayResultRow(it.key, it.value) }
}

private fun pureVoiceDisplayResultRow(label: String, value: String): Pair<String, String> {
    return pureVoiceResultLabel(label) to pureVoiceResultValue(value)
}

private fun pureVoiceResultLabel(label: String): String {
    return when (label.trim()) {
        "联系人", "contactName" -> currentAppText(label, "Contact")
        "联系电话", "手机号", "contactPhone" -> currentAppText(label, "Phone")
        "电话" -> currentAppText(label, "Phone")
        "时间", "用餐时间", "reservationTime", "mainDate", "到店时间" -> currentAppText(label, "Time")
        "人数", "用餐人数", "partySize", "guestCount" -> currentAppText(label, "Party Size")
        "目的", "需求", "通话事项" -> currentAppText(label, "Purpose")
        "重点" -> currentAppText(label, "Details")
        "补充" -> currentAppText(label, "Additional Details")
        "餐厅", "restaurantName" -> currentAppText(label, "Restaurant")
        "酒店", "hotelName" -> currentAppText(label, "Hotel")
        "目标", "targetName" -> currentAppText(label, "Target")
        "包房", "包房情况", "包间", "privateRoom", "needPrivateRoom" -> currentAppText(label, "Private Room")
        "低消", "低消信息" -> currentAppText(label, "Minimum Spend")
        "座位" -> currentAppText(label, "Seating")
        "入住", "入住日期" -> currentAppText(label, "Check-in")
        "离店", "离店日期" -> currentAppText(label, "Check-out")
        "房型" -> currentAppText(label, "Room Type")
        else -> pureVoiceResultValue(label)
    }
}

private fun pureVoiceResultValue(value: String): String {
    val trimmed = value.trim()
    if (trimmed.isBlank()) return ""
    return if (currentAppText("中文", "English") == "English") {
        sanitizeUserFacingNetworkText(trimmed, VoiceLanguage.English)
    } else {
        trimmed
    }
}

private fun pureVoiceMeaningfulCallTarget(value: String): String? {
    val trimmed = value.trim()
    if (trimmed.isBlank()) return null
    val compact = trimmed.replace("\\s+".toRegex(), "")
    val lower = compact.lowercase()
    return trimmed.takeUnless {
        lower in setOf("ai助理", "ai外呼", "chaken.ai", "chakenai", "目标对象")
    }
}

private fun pureVoiceMeaningfulCallPurpose(value: String): String? {
    val trimmed = value.trim()
    if (trimmed.isBlank() || Regex("""\d{7,}""").containsMatchIn(trimmed)) return null
    val compact = trimmed.replace("\\s+".toRegex(), "")
    val lower = compact.lowercase()
    return trimmed.takeUnless {
        lower in setOf("实时外呼", "ai外呼", "通话中")
    }
}

private fun pureVoiceExtractResultFields(source: String): List<Pair<String, String>> {
    if (source.isBlank()) return emptyList()
    val labelMap = mapOf(
        "用餐时间" to "时间",
        "用餐人数" to "人数",
        "包房情况" to "包房",
        "低消信息" to "低消",
        "入住日期" to "入住",
        "离店日期" to "离店",
        "房型" to "房型",
        "到店时间" to "到店",
        "restaurantName" to "餐厅",
        "hotelName" to "酒店",
        "targetName" to "目标",
        "reservationTime" to "时间",
        "mainDate" to "时间",
        "partySize" to "人数",
        "guestCount" to "人数",
        "needPrivateRoom" to "包房",
        "privateRoom" to "包房",
        "contactName" to "联系人",
        "contactPhone" to "联系电话",
        "联系人" to "联系人",
        "联系电话" to "联系电话",
        "手机号" to "联系电话",
        "座位" to "座位"
    )
    val rows = linkedMapOf<String, String>()
    Regex("(?:通话任务字段[:：])?\\s*(restaurantName|hotelName|targetName|reservationTime|mainDate|partySize|guestCount|needPrivateRoom|privateRoom|contactName|contactPhone|用餐时间|用餐人数|包房情况|低消信息|入住日期|离店日期|房型|到店时间|联系人|联系电话|手机号|座位|餐厅|酒店|时间|人数|包房|包间)[:：]\\s*([^。；;\\n]+)")
        .findAll(source)
        .forEach { match ->
            val rawLabel = match.groupValues.getOrNull(1).orEmpty()
            val value = pureVoiceNormalizeResultFieldValue(rawLabel, match.groupValues.getOrNull(2).orEmpty().trim())
            val label = labelMap[rawLabel] ?: rawLabel
            if (label.isNotBlank() && value.isNotBlank()) rows[label] = value
        }

    pureVoiceExtractNaturalBookingFields(source).forEach { (label, value) ->
        if (value.isNotBlank() && (label == "包房" || label == "座位" || rows[label].isNullOrBlank())) {
            rows[label] = value
        }
    }
    return rows.entries.map { it.key to it.value }
}

private fun pureVoiceNormalizeResultFieldValue(label: String, value: String): String {
    val trimmed = value.trim()
    if (trimmed.isBlank()) return ""
    return when (label) {
        "reservationTime", "mainDate" -> trimmed.replace('T', ' ')
        "partySize", "guestCount", "用餐人数", "人数" -> {
            if (Regex("""^\d+$""").matches(trimmed)) {
                currentAppText("${trimmed}人", "$trimmed people")
            } else {
                trimmed
            }
        }
        "needPrivateRoom", "privateRoom" -> {
            when (trimmed.lowercase()) {
                "true", "yes", "1" -> currentAppText("需要包房", "Private room needed")
                "false", "no", "0" -> currentAppText("不需要包房", "No private room needed")
                else -> trimmed
            }
        }
        else -> trimmed
    }
}

private fun pureVoiceExtractNaturalBookingFields(source: String): List<Pair<String, String>> {
    val compact = source.replace("\\s+".toRegex(), "")
    val rows = linkedMapOf<String, String>()
    Regex("""(?:今天|今晚|明天|后天)?(?:早上|上午|中午|下午|晚上)?\d{1,2}点(?:半|\d{1,2}分?)?""")
        .find(compact)
        ?.value
        ?.takeIf { rows["时间"].isNullOrBlank() }
        ?.let { rows["时间"] = it }
    Regex("""(?:我们)?([一二三四五六七八九十两俩\d]+)(?:个)?(?:人|位)""")
        .find(compact)
        ?.groupValues
        ?.getOrNull(1)
        ?.let { pureVoiceChineseNumberTextToDisplay(it) }
        ?.let { rows["人数"] = it }
    if (pureVoiceLooksLikeNoPrivateRoom(compact)) {
        rows["包房"] = currentAppText("无", "No")
    }
    if (Regex("""大厅(可以|可|有|能)|大点的位置|空的桌子|桌子""").containsMatchIn(compact)) {
        rows["座位"] = currentAppText("大厅", "Main hall")
    }
    Regex("""([\u4e00-\u9fa5]{1,4}先生|[\u4e00-\u9fa5]{1,4}女士)""")
        .find(source)
        ?.value
        ?.let { rows["联系人"] = it }
    Regex("""尾号\s*\d{3,4}|1[3-9]\d{9}""")
        .find(compact)
        ?.value
        ?.let { rows["联系电话"] = it }
    Regex("""低消[^。；;\n]*""")
        .find(source)
        ?.value
        ?.takeIf { it.length <= 30 }
        ?.let { rows["低消"] = it }
    return rows.entries.map { it.key to it.value }
}

private fun pureVoiceExtractTranscriptBookingFields(transcript: List<TranscriptLine>): List<Pair<String, String>> {
    val rows = linkedMapOf<String, String>()
    val dialogue = transcript.filter { it.role == TranscriptRole.Assistant || it.role == TranscriptRole.Remote }
    dialogue.forEachIndexed { index, line ->
        if (line.role != TranscriptRole.Remote) return@forEachIndexed
        val remoteText = pureVoiceCompactText(line.text)
        if (remoteText.isBlank()) return@forEachIndexed
        val previousAssistant = dialogue
            .subList(0, index)
            .lastOrNull { it.role == TranscriptRole.Assistant }
            ?.text
            ?.let(::pureVoiceCompactText)
            .orEmpty()

        if (pureVoiceLooksLikeNoPrivateRoom(remoteText)) {
            rows["包房"] = currentAppText("无", "No")
        } else if (
            previousAssistant.contains("包房") ||
            previousAssistant.contains("包间") ||
            previousAssistant.contains("包厢")
        ) {
            if (pureVoiceRemoteConfirmsPrivateRoom(remoteText) && rows["包房"] !in setOf("无", "No")) {
                rows["包房"] = currentAppText("有", "Yes")
            }
        }

        if (Regex("""大厅(可以|可|有|能)|大点的位置|空的桌子|桌子""").containsMatchIn(remoteText)) {
            rows["座位"] = currentAppText("大厅", "Main hall")
        }
    }
    return rows.entries.map { it.key to it.value }
}

private fun pureVoiceLooksLikeNoPrivateRoom(compact: String): Boolean {
    if (compact.isBlank()) return false
    return Regex("""包[房间厢](没有|没了|无|订完|满了)|(?:没有|没了|无)(?:可订|可用|剩余)?包[房间厢]""")
        .containsMatchIn(compact)
}

private fun pureVoiceRemoteConfirmsPrivateRoom(compact: String): Boolean {
    if (compact.isBlank() || pureVoiceLooksLikeNoPrivateRoom(compact)) return false
    if (Regex("""有(的)?包[房间厢]|包[房间厢](可以|能|有|没问题)""").containsMatchIn(compact)) {
        return true
    }
    return Regex("""^(嗯|哦|哎|啊|好|好的|可以|可以的|行|行的|是的|对|对的|有|有的|没问题)[。！!，,]*$""")
        .matches(compact)
}

private fun pureVoiceCompactText(value: String): String =
    value.replace("\\s+".toRegex(), "")

private fun pureVoiceChineseNumberTextToDisplay(value: String): String {
    val normalized = value.trim()
    if (normalized.isBlank()) return ""
    return if (Regex("""^\d+$""").matches(normalized)) {
        currentAppText("${normalized}人", "$normalized people")
    } else {
        currentAppText("${normalized}人", "$normalized people")
    }
}

internal fun pureVoiceFailureReason(data: CallPageData): String {
    val detail = pureVoiceCallResultDetail(data).orEmpty()
    if (detail.isBlank()) return ""
    val withoutTitle = detail
        .replace(Regex("^预订结果[:：]\\s*"), "")
        .replace(Regex("^AI代打结果[:：]\\s*"), "")
        .trim()
    val lines = withoutTitle
        .lineSequence()
        .map { it.trim() }
        .filter { it.isNotBlank() }
        .toList()
    return lines.firstOrNull { line ->
        Regex("执行异常|失败|未成功|未完成|未接通|不匹配|不符|无空位|没位|取消|结果不明确|无法判断|稍后")
            .containsMatchIn(line)
    } ?: lines.firstOrNull().orEmpty()
}
