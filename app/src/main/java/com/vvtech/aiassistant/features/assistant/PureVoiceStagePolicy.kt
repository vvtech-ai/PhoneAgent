package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.features.assistant_pure_voice.PureVoiceConversationStepProjector
import com.vvtech.aiassistant.features.assistant_tasks.looksLikeTerminalCallResultStatus

internal fun pureVoiceSummaryLineItem(line: String): Pair<String, String> {
    val normalized = line.trim()
    if (normalized.isBlank()) return "信息" to ""
    val separatorIndex = listOf(
        normalized.indexOf('：'),
        normalized.indexOf(':')
    ).filter { it >= 0 }.minOrNull()
    return if (separatorIndex != null && separatorIndex > 0) {
        normalized.substring(0, separatorIndex).trim() to
            normalized.substring(separatorIndex + 1).trim()
    } else {
        "信息" to normalized
    }
}

internal fun pureVoiceDisplaySteps(steps: List<ClarificationStep>): List<ClarificationStep> =
    PureVoiceConversationStepProjector.project(steps)

internal fun pureVoiceLooksLikeCallResultStatus(status: String): Boolean {
    return looksLikeTerminalCallResultStatus(status)
}

internal fun pureVoiceLooksLikePendingCallResultStatus(status: String): Boolean {
    val normalized = status.trim()
    return normalized.contains("正在确认通话结果") ||
        normalized.contains("通话结果确认中") ||
        normalized.contains("确认通话结果")
}

internal fun pureVoiceUserReplyIndexAfter(
    steps: List<ClarificationStep>,
    assistantPromptIndex: Int
): Int {
    if (assistantPromptIndex < 0) return -1
    return steps.indexOfFirstIndexed { index, step ->
        index > assistantPromptIndex && step.role == VoiceRole.User
    }
}

private inline fun <T> List<T>.indexOfFirstIndexed(predicate: (Int, T) -> Boolean): Int {
    for (index in indices) {
        if (predicate(index, this[index])) return index
    }
    return -1
}

internal fun pureVoiceContactConfirmedSteps(
    summary: SummaryData?,
    contactPromptText: String,
    allSteps: List<ClarificationStep>
): List<String> {
    val contact = pureVoiceConfirmedContactDisplay(summary, contactPromptText, allSteps)
    return listOf(
        "确认预留联系方式：$contact",
        "进入补充细节阶段"
    )
}

internal fun pureVoiceConfirmedContactDisplay(
    summary: SummaryData?,
    contactPromptText: String,
    allSteps: List<ClarificationStep>
): String {
    summary?.contactValue?.trim()?.takeIf { it.isNotBlank() }?.let { return it }
    val allText = (allSteps.joinToString(" ") { it.text } + " " + contactPromptText).trim()
    Regex("1[3-9]\\d{9}").find(allText)?.value?.let { return it }
    Regex("""尾号\s*(\d{3,4})""").find(allText)?.groupValues?.getOrNull(1)?.let { return "***$it" }
    Regex("""ending\s+in\s+(\d{3,4})""", RegexOption.IGNORE_CASE).find(allText)
        ?.groupValues
        ?.getOrNull(1)
        ?.let { return "***$it" }
    return "已确认"
}

internal fun pureVoiceDetailConfirmedSteps(replyText: String): List<String> {
    val normalized = replyText.trim()
    val detailSteps = buildList {
        if (normalized.contains("低消")) add("记录补充要求：询问低消")
        if (normalized.contains("包房") || normalized.contains("包间") || normalized.contains("大厅")) {
            add(
                if (normalized.contains("大厅")) {
                    "记录补充要求：无包房可改大厅"
                } else {
                    "记录补充要求：确认包房/包间要求"
                }
            )
        }
        if (isEmpty() && normalized.isNotBlank()) {
            add(
                if (pureVoiceLooksLikeSkipDetail(normalized)) {
                    "记录补充要求：跳过补充"
                } else {
                    "记录补充要求：${normalized.take(18)}"
                }
            )
        }
    }
    return detailSteps + listOf(
        "汇总全部任务信息",
        "生成通话脚本和拨打计划"
    )
}

internal fun pureVoiceLooksLikeSkipDetail(text: String): Boolean {
    val normalized = text.lowercase()
    return listOf("跳过", "不用", "没有", "无", "skip", "no").any { normalized.contains(it) }
}

internal fun pureVoiceLooksLikeContactPrompt(text: String): Boolean {
    val normalized = text.lowercase()
    return listOf("号码", "联系方式", "联系人", "预订人", "预留", "phone", "contact", "電話")
        .any { normalized.contains(it) } &&
        !pureVoiceLooksLikeDetailPrompt(text)
}

internal fun pureVoiceLooksLikeDetailPrompt(text: String): Boolean {
    val normalized = text.lowercase()
    return listOf("补充", "低消", "包房", "包间", "大厅", "跳过", "detail", "additional", "minimum spend")
        .any { normalized.contains(it) }
}

internal fun pureVoiceLooksLikeSelectionPrompt(text: String): Boolean {
    val normalized = text.lowercase()
    return listOf(
        "请选择", "选择", "选一个", "候选", "底部列表", "第一个", "第二个", "第三个",
        "choose", "select", "candidate", "option", "リスト", "選んで"
    ).any { normalized.contains(it) }
}

internal fun pureVoiceIntentItems(
    taskScene: String,
    sceneType: String?,
    firstUserText: String,
    selectionSheet: SelectionSheetData?,
    summary: SummaryData?,
    detailSupplement: DetailSupplementPageData?
): List<String> {
    val normalizedScene = pureVoiceNormalizedSceneType(sceneType ?: detailSupplement?.sceneType)
    val target = summary?.target?.takeIf { it.isNotBlank() }
        ?: detailSupplement?.targetName?.takeIf { it.isNotBlank() }
        ?: selectionSheet?.options?.firstOrNull()?.title?.takeIf { it.isNotBlank() }
        ?: pureVoiceExtractTargetSlot(firstUserText, normalizedScene)
    val time = summary?.time?.takeIf { it.isNotBlank() && it != "待确认" }
        ?: pureVoiceExtractTimeSlot(firstUserText)
    val party = pureVoiceExtractPartySlot(firstUserText, summary)
    val phone = pureVoiceExtractPhoneSlot(firstUserText, summary)
    val extra = summary?.extra?.takeIf { it.isNotBlank() && it != "待确认" }
    val contact = summary?.contactValue?.takeIf { it.isNotBlank() }
    val detail = summary?.detailValue?.takeIf { it.isNotBlank() }
    return buildList {
        fun addSlot(label: String, value: String?) {
            val normalized = value?.trim()?.takeIf { it.isNotBlank() && it != "待确认" } ?: return
            add("$label：$normalized")
        }
        add("任务类型：$taskScene")
        when (normalizedScene) {
            "FOOD_ORDERING" -> {
                addSlot("餐厅", target)
                addSlot("时间", time)
                addSlot("人数", party)
                addSlot("预留信息", contact)
                addSlot("补充要求", detail ?: extra)
            }
            "HOTEL_BOOKING" -> {
                addSlot("酒店", target)
                addSlot("入住时间", time)
                addSlot("人数/房间", party ?: extra)
                addSlot("预留信息", contact)
                addSlot("偏好", detail)
            }
            "AI_CALL" -> {
                addSlot("代打对象", target)
                addSlot("电话号码", phone)
                addSlot("通话事项", extra)
                addSlot("补充信息", detail)
            }
            "FLIGHT_BOOKING" -> {
                addSlot("航班/路线", target)
                addSlot("出发时间", time)
                addSlot("乘机人", contact)
                addSlot("补充要求", detail ?: extra)
            }
            else -> {
                addSlot("目标", target)
                addSlot(summary?.timeLabel ?: "时间", time)
                addSlot(summary?.extraLabel ?: "补充", extra)
                addSlot(summary?.contactLabel ?: "预留信息", contact)
                addSlot(summary?.detailLabel ?: "补充要求", detail)
            }
        }
    }.take(6)
}

internal fun pureVoiceResolvedTaskScene(
    sceneType: String?,
    summary: SummaryData?,
    detailSupplement: DetailSupplementPageData?
): String? {
    val normalizedScene = pureVoiceNormalizedSceneType(sceneType ?: detailSupplement?.sceneType)
    return when (normalizedScene) {
        "FOOD_ORDERING" -> "餐厅预订"
        "HOTEL_BOOKING" -> "酒店预订"
        "AI_CALL" -> "AI代打"
        "FLIGHT_BOOKING" -> "机票预订"
        else -> summary?.task
            ?.takeIf { it.contains("餐厅预订") || it.contains("酒店预订") || it.contains("AI代打") || it.contains("机票预订") }
    }
}

internal fun pureVoiceNormalizedSceneType(sceneType: String?): String {
    val normalized = sceneType.orEmpty().trim().uppercase()
    return when (normalized) {
        "FOOD", "FOOD_ORDER", "RESTAURANT", "RESTAURANT_BOOKING" -> "FOOD_ORDERING"
        "HOTEL", "HOTEL_RESERVATION" -> "HOTEL_BOOKING"
        "CALL", "PHONE_CALL", "MAKE_CALL", "OUTBOUND_CALL", "GENERAL",
        "MESSAGE_RELAY", "MEETING_NOTIFICATION", "NOTIFICATION" -> "AI_CALL"
        "FLIGHT", "AIR_TICKET", "TICKET_BOOKING" -> "FLIGHT_BOOKING"
        else -> normalized
    }
}

internal fun pureVoiceExtractTargetSlot(text: String, sceneType: String): String? {
    val normalized = text.trim()
    if (normalized.isBlank()) return null
    val match = when (sceneType) {
        "FOOD_ORDERING" -> Regex("(?:订|预订|定|约)(?:一下|个)?([^，。,.；;]+?)(?:今天|今晚|明天|后天|\\d|[一二三四五六七八九十两]+个?人|[一二三四五六七八九十两]+位|包房|包间|低消|$)")
            .find(normalized)
        "HOTEL_BOOKING" -> Regex("(?:订|预订|定)(?:一下|个)?([^，。,.；;]+?)(?:酒店|今天|今晚|明天|后天|入住|\\d|$)")
            .find(normalized)
        "AI_CALL" -> Regex("(?:给|帮我给|联系|打给|打电话给)([^，。,.；;\\d]+)")
            .find(normalized)
        else -> null
    }
    return match?.groupValues?.getOrNull(1)?.trim()?.takeIf { it.length >= 2 }
}

internal fun pureVoiceExtractTimeSlot(text: String): String? {
    val normalized = text.trim()
    return Regex("(今天|今晚|明天|后天)?\\s*(早上|上午|中午|下午|晚上)?\\s*\\d{1,2}\\s*点(?:半|\\d{1,2}分?)?")
        .find(normalized)
        ?.value
        ?.replace("\\s+".toRegex(), "")
        ?.takeIf { it.isNotBlank() }
}

internal fun pureVoiceExtractPartySlot(text: String, summary: SummaryData?): String? {
    val fromSummary = summary?.extra?.takeIf {
        Regex("\\d+\\s*(人|位|个)|[一二三四五六七八九十两]+\\s*(人|位|个)").containsMatchIn(it)
    }
    if (!fromSummary.isNullOrBlank()) return fromSummary
    return Regex("(\\d+\\s*(?:个人|人|位)|[一二三四五六七八九十两]+\\s*(?:个人|人|位))")
        .find(text)
        ?.value
        ?.replace("\\s+".toRegex(), "")
}

internal fun pureVoiceExtractPhoneSlot(text: String, summary: SummaryData?): String? {
    val source = listOf(summary?.time, summary?.target, summary?.contactValue, text)
        .joinToString(" ")
    return Regex("1[3-9]\\d{9}").find(source)?.value
}

internal fun pureVoiceContactThinkingSteps(
    summary: SummaryData?,
    detailSupplement: DetailSupplementPageData?,
    contactPromptText: String,
    allSteps: List<ClarificationStep>
): List<String> {
    val target = summary?.target?.takeIf { it.isNotBlank() }
        ?: detailSupplement?.targetName?.takeIf { it.isNotBlank() }
    val contact = summary?.contactValue?.takeIf { it.isNotBlank() }
        ?: pureVoiceConfirmedContactDisplay(summary, contactPromptText, allSteps).takeUnless { it == "已确认" }
    return buildList {
        add("锁定目标：${target ?: "待确认对象"}")
        add("检查预订人联系信息")
        add(if (contact != null) "发现已保存联系人：$contact" else "等待确认预留联系方式")
    }
}

internal fun pureVoiceSearchQuery(
    firstUserText: String,
    summary: SummaryData?,
    detailSupplement: DetailSupplementPageData?
): String {
    return summary?.target?.takeIf { it.isNotBlank() }
        ?: detailSupplement?.targetName?.takeIf { it.isNotBlank() }
        ?: firstUserText.take(18).ifBlank { "用户需求" }
}

internal fun pureVoiceLiveLabel(
    state: PureVoiceState,
    voiceLanguage: VoiceLanguage,
    status: String,
    showCallPage: Boolean
): String {
    if (showCallPage) return "通话进行中..."
    val normalizedStatus = sanitizeUserFacingNetworkText(status, voiceLanguage).trim()
    return when (state) {
        PureVoiceState.Standby -> pureVoiceStandbyLiveLabel(normalizedStatus, voiceLanguage)
        PureVoiceState.Listening -> voiceLanguage.listeningText.ifBlank { "语音识别中..." }
        PureVoiceState.AiThinking -> voiceLanguage.aiThinkingText.ifBlank { "AI 思考中..." }
        PureVoiceState.AiSpeaking -> voiceLanguage.aiSpeakingText.ifBlank { "AI 回复中..." }
    }
}

private fun pureVoiceStandbyLiveLabel(status: String, voiceLanguage: VoiceLanguage): String {
    val staleResumePrompt = listOf(
        "对话已恢复，点击继续说话",
        "历史记录已恢复",
        "已恢复对话，可继续补充",
        "已暂停，返回后可继续",
        "已暂停，点击继续说话",
        "你可以再点一下麦克风继续说",
        "请说出你的需求。",
        "请按住下方语音按钮，说出你的需求。",
        voiceLanguage.firstWelcome,
        voiceLanguage.repeatWelcome,
        voiceLanguage.standbyText,
        "Voice is ready. Please continue.",
        "音声入力を続けられます。"
    ).any { status == it }
    val fallback = when (voiceLanguage) {
        VoiceLanguage.English -> "Voice standby..."
        VoiceLanguage.Japanese -> "音声待機中..."
        VoiceLanguage.Chinese -> "语音待命中..."
    }
    return if (status.isNotBlank() && !staleResumePrompt) status else fallback
}

internal fun pureVoiceSanitizeStepForDisplay(
    step: ClarificationStep,
    voiceLanguage: VoiceLanguage
): ClarificationStep {
    if (step.role == VoiceRole.User) return step
    return step.copy(
        text = sanitizeUserFacingNetworkText(step.text, voiceLanguage),
        status = sanitizeUserFacingNetworkText(step.status, voiceLanguage),
        thinking = step.thinking
            ?.lineSequence()
            ?.map { sanitizeUserFacingNetworkText(it.trim(), voiceLanguage) }
            ?.filter { it.isNotBlank() }
            ?.joinToString("\n")
            ?.takeIf { it.isNotBlank() },
        toolCalls = step.toolCalls?.map { tool ->
            tool.copy(
                args = sanitizeUserFacingNetworkText(tool.args, voiceLanguage),
                result = sanitizeUserFacingNetworkText(tool.result, voiceLanguage)
            )
        },
        toolCards = step.toolCards.map { tool ->
            tool.copy(
                body = sanitizeUserFacingNetworkText(tool.body, voiceLanguage),
                result = sanitizeUserFacingNetworkText(tool.result, voiceLanguage),
                status = sanitizeUserFacingNetworkText(tool.status, voiceLanguage)
            )
        },
        partialToolCalls = step.partialToolCalls.map { tool ->
            tool.copy(
                argsPreview = sanitizeUserFacingNetworkText(tool.argsPreview, voiceLanguage),
                result = tool.result?.let { sanitizeUserFacingNetworkText(it, voiceLanguage) }
            )
        }
    )
}

internal fun pureVoiceSanitizeCallPageData(
    data: CallPageData,
    voiceLanguage: VoiceLanguage
): CallPageData {
    return data.copy(
        status = sanitizeUserFacingNetworkText(data.status, voiceLanguage),
        transcript = data.transcript.map { line ->
            line.copy(text = sanitizeUserFacingNetworkText(line.text, voiceLanguage))
        }
    )
}

internal fun pureVoiceToolIcon(toolName: String, methodLabel: String): String {
    return when (toolName) {
        "search" -> "S"
        "askUser" -> "A"
        "showOptions" -> "O"
        "makeCall" -> "C"
        "stageReport" -> "R"
        else -> methodLabel.firstOrNull()?.uppercaseChar()?.toString() ?: "T"
    }
}
