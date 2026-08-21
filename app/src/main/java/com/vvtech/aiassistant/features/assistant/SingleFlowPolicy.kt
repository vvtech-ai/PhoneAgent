package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import com.vvtech.aiassistant.features.assistant_tasks.looksLikeTerminalCallResultStatus
internal const val SfAllowPrivateRoomFallbackToHallQuestionId = "allowPrivateRoomFallbackToHall"
private val SfVoiceFoodDetailQuestionIds = setOf(
    "needPrivateRoom",
    "askPrivateRoomMinimumSpend",
    SfAllowPrivateRoomFallbackToHallQuestionId
)

internal data class SfRestaurantOption(
    val id: String,
    val alias: String,
    val name: String,
    val note: String,
    val tags: List<String>
)

internal sealed class SfThreadItem(open val id: Long) {
    data class UserText(
        override val id: Long,
        val text: String
    ) : SfThreadItem(id)

    data class UserWave(
        override val id: Long
    ) : SfThreadItem(id)

    data class AiText(
        override val id: Long,
        val text: String
    ) : SfThreadItem(id)

    data class AiThinking(
        override val id: Long,
        val steps: List<String>
    ) : SfThreadItem(id)

    data class AiCta(
        override val id: Long,
        val text: String
    ) : SfThreadItem(id)

    data class Summary(
        override val id: Long,
        val text: String
    ) : SfThreadItem(id)

    data class Options(
        override val id: Long,
        val options: List<SfRestaurantOption>
    ) : SfThreadItem(id)
}

internal fun sfStageLabels(): List<String> = listOf(
    currentAppText("任务下达", "Task Request"),
    currentAppText("需求确认", "Confirm Details"),
    currentAppText("执行通话", "Start Call"),
    currentAppText("执行结果", "Results")
)

/** 纯语音模式右侧调试悬浮面板，上线前设为 false 关闭 */
internal const val ShowVoiceDebugOverlay = false

// Track whether pure-voice welcome message has been played in this process
internal var pvWelcomePlayedThisProcess = false

internal fun sfDefaultRestaurants(): List<SfRestaurantOption> = listOf(
    SfRestaurantOption(
        id = "1",
        alias = "西堤",
        name = "西堤牛排北京国贸店",
        note = "双人晚餐体验稳定，电话确认效率高。",
        tags = listOf("牛排", "2.1km", "常去")
    ),
    SfRestaurantOption(
        id = "2",
        alias = "西贝",
        name = "西贝莜面村国贸店",
        note = "大厅翻台快，适合需要尽快确认席位的场景。",
        tags = listOf("西北", "热门", "等位短")
    ),
    SfRestaurantOption(
        id = "3",
        alias = "新荣记",
        name = "新荣记国贸店",
        note = "环境更安静，需提前沟通包间和到店时间。",
        tags = listOf("融合", "安静", "可停车")
    )
)

internal fun sfDefaultThinkingSteps(text: String): List<String> {
    return when {
        text.contains("候选") || text.contains("第几个") -> listOf(
            "进入需求确认子流程",
            "识别为餐厅候选选择任务",
            "召回候选门店并按相关性排序",
            "生成可回复“名称/第几个”的引导语"
        )

        text.contains("包间") || text.contains("处理方式") -> listOf(
            "抽取约束条件（包间/大厅）",
            "评估兜底处理策略可行性",
            "检查语义歧义与冲突条件",
            "生成最短追问文案"
        )

        text.contains("通话") || text.contains("状态") -> listOf(
            "同步通话状态机",
            "推进任务阶段与回执节点",
            "写入本轮上下文与结果摘要"
        )

        else -> listOf(
            "接收并标准化用户输入",
            "分类当前任务类型",
            "补全时间/人数/门店等关键信息",
            "生成下一步可执行指令"
        )
    }
}

internal fun sfParseRestaurantDecision(
    input: String,
    options: List<SfRestaurantOption>
): SfRestaurantOption? {
    val condensed = input.replace("\\s+".toRegex(), "")
    if (Regex("第?一|第一家|一号|1").containsMatchIn(condensed)) return options.getOrNull(0)
    if (Regex("第?二|第二家|二号|2").containsMatchIn(condensed)) return options.getOrNull(1)
    if (Regex("第?三|第三家|三号|3").containsMatchIn(condensed)) return options.getOrNull(2)
    return options.firstOrNull { condensed.contains(it.alias) || condensed.contains(it.name.replace("\\s+".toRegex(), "")) }
}

internal fun sfParseFallback(input: String): String {
    return when {
        Regex("不可以|不要|不行|不接受").containsMatchIn(input) -> "无包间则不预订"
        Regex("可以|行|同意|大厅").containsMatchIn(input) -> "无包间可改订大厅"
        else -> ""
    }
}

internal fun sfExtractTimeAndParty(
    text: String,
    currentTime: String,
    currentParty: String
): Pair<String, String> {
    var time = currentTime
    var party = currentParty
    val timeRegex = Regex("(今晚|明晚|后天|今天)?\\s*([0-2]?\\d)\\s*点")
    val peopleRegex = Regex("([一二两三四五六七八九十\\d]+)\\s*(位|人)")
    val timeMatch = timeRegex.find(text)
    val peopleMatch = peopleRegex.find(text)
    if (timeMatch != null) {
        val prefix = timeMatch.groupValues[1].ifBlank { "今晚" }
        val hour = timeMatch.groupValues[2]
        time = "$prefix ${hour}:00"
    }
    if (peopleMatch != null) {
        party = "${peopleMatch.groupValues[1]}${peopleMatch.groupValues[2]}"
    }
    return time to party
}

internal fun sfSplitRestaurantName(fullName: String): Pair<String, String> {
    if (fullName.contains("北京国贸店")) {
        return "西堤牛排" to "北京国贸店"
    }
    if (fullName.contains("国贸店")) {
        return fullName.replace("国贸店", "") to "国贸店"
    }
    if (fullName.contains("店")) {
        val idx = fullName.lastIndexOf("店")
        val left = fullName.substring(0, idx + 1).ifBlank { fullName }
        return left to "目标门店"
    }
    return fullName to "目标门店"
}

internal fun sfFormatCallTime(seconds: Int): String {
    val mm = (seconds / 60).toString().padStart(2, '0')
    val ss = (seconds % 60).toString().padStart(2, '0')
    return "$mm:$ss"
}

internal fun sfHasRealRestaurantFlowState(state: Index9AssistantUiState): Boolean {
    return state.clarificationSteps.isNotEmpty() ||
        !state.liveUserTranscript.isNullOrBlank() ||
        !state.liveAssistantTranscript.isNullOrBlank() ||
        state.selectionSheet != null ||
        state.summary != null ||
        state.detailSupplement != null ||
        state.showAiCallPage ||
        state.voiceConnecting ||
        state.voiceActive ||
        state.listening ||
        state.processingTurn ||
        !state.error.isNullOrBlank() ||
        state.taskId != null
}

internal fun sfVoiceDetailSupplement(supplement: DetailSupplementPageData): DetailSupplementPageData {
    if (supplement.sceneType != "FOOD_ORDERING") {
        return supplement
    }
    val filtered = supplement.questions
        .filter { it.questionId in SfVoiceFoodDetailQuestionIds }
        .toMutableList()
    if (filtered.none { it.questionId == "needPrivateRoom" }) {
        filtered.add(
            DetailSupplementQuestionData(
                questionId = "needPrivateRoom",
                prompt = "需要包房"
            )
        )
    }
    if (filtered.none { it.questionId == "askPrivateRoomMinimumSpend" }) {
        filtered.add(
            DetailSupplementQuestionData(
                questionId = "askPrivateRoomMinimumSpend",
                prompt = "需要确认包房低消",
                dependsOnQuestionId = "needPrivateRoom",
                dependsOnAnswer = "true"
            )
        )
    }
    if (filtered.none { it.questionId == SfAllowPrivateRoomFallbackToHallQuestionId }) {
        filtered.add(
            DetailSupplementQuestionData(
                questionId = SfAllowPrivateRoomFallbackToHallQuestionId,
                prompt = "允许无包房时改订大厅",
                dependsOnQuestionId = "needPrivateRoom",
                dependsOnAnswer = "true"
            )
        )
    }
    val ordered = SfVoiceFoodDetailQuestionIds.mapNotNull { id ->
        filtered.firstOrNull { it.questionId == id }
    }
    return supplement.copy(
        intro = "语音模式下只确认包房、包房低消，以及无包房时是否可改大厅。",
        questions = ordered
    )
}

internal fun sfVoiceDetailPrompt(): String {
    return "还有补充要求吗？你可以说都要、只要包房、只问低消、无包房可以改大厅，或者直接说跳过。如果要包房，我会再确认没有包房是否可以改大厅。"
}

internal fun sfVoiceDetailPromptForScene(sceneType: String): String {
    return when (sceneType) {
        "HOTEL_BOOKING" ->
            "还有酒店偏好要补充吗？你可以说无烟房、高楼层、远离马路、窗边房、停车位、延迟退房，或者直接说跳过。"
        else -> sfVoiceDetailPrompt()
    }
}

internal fun sfSummaryVoiceSignature(taskId: String?, summary: SummaryData): String {
    return listOf(
        taskId.orEmpty(),
        summary.task,
        summary.target,
        summary.time,
        summary.extra,
        summary.contactValue.orEmpty(),
        summary.detailValue.orEmpty()
    ).joinToString("|").trim()
}

internal fun sfRealRestaurantStage(state: Index9AssistantUiState): Int {
    val status = state.taskStatus.uppercase()
    val hasRunningBatchCall = state.clarificationSteps.any { step ->
        step.callStatusEvents.isNotEmpty() ||
            step.batchCallResult?.status.equals("RUNNING", ignoreCase = true)
    }
    val hasFinishedBatchCall = state.clarificationSteps.any { step ->
        val result = step.batchCallResult
        result != null && !result.status.equals("RUNNING", ignoreCase = true)
    }
    val progressText = state.clarificationSteps.joinToString("\n") { step ->
        buildString {
            appendLine(step.text)
            appendLine(step.thinking.orEmpty())
            step.callStatusEvents.forEach(::appendLine)
            step.batchCallResult?.let { result ->
                appendLine(result.status)
                appendLine(result.headline)
            }
        }
    }
    val narratingFinishedBatchResult = hasFinishedBatchCall &&
        !state.processingTurn &&
        state.liveUserTranscript.isNullOrBlank() &&
        (
            state.apiTtsPlaying ||
                state.localTtsSpeaking ||
                !state.liveAssistantTranscript.isNullOrBlank()
            )
    val continuingAfterCallResult = state.agentCallResult == null &&
        !state.showAiCallPage &&
        !narratingFinishedBatchResult &&
        (
            state.processingTurn ||
                state.listening ||
                state.voiceActive ||
                state.voiceConnecting ||
                state.apiAsrListening ||
                state.apiTtsPlaying ||
                state.localTtsSpeaking ||
                !state.liveUserTranscript.isNullOrBlank() ||
                !state.liveAssistantTranscript.isNullOrBlank()
            )
    val hasCompletedCall = !continuingAfterCallResult && !state.showAiCallPage && (
        hasFinishedBatchCall ||
            state.agentCallResult != null ||
            progressText.contains("通话已结束") ||
            progressText.contains("任务已完成") ||
        state.callPageData.transcript.any { it.role != TranscriptRole.Note } ||
            sfLooksLikeFinishedCallStatus(state.callPageData.status)
        )
    val hasCallExecution = state.showAiCallPage ||
        hasRunningBatchCall ||
        state.agentCallSpec != null ||
        progressText.contains("任务确认完毕") ||
        progressText.contains("拨打预订电话") ||
        progressText.contains("正在通话") ||
        state.status.contains("拨打电话") ||
        state.status.contains("通话中")
    val hasRequirementConfirmation = state.summary != null ||
        state.selectionSheet != null ||
        state.detailSupplement != null ||
        progressText.contains("识别当前任务为") ||
        progressText.contains("补全") ||
        progressText.contains("召回候选") ||
        progressText.contains("搜到的结果") ||
        progressText.contains("锁定目标") ||
        progressText.contains("检查预订人联系信息") ||
        progressText.contains("确认预留联系方式") ||
        progressText.contains("记录补充要求")
    return when {
        hasCompletedCall -> 4
        !continuingAfterCallResult &&
            status in setOf("SUCCESS", "COMPLETED", "FAILED", "CANCELLED", "CANCELED") -> 4
        hasCallExecution -> 3
        hasRequirementConfirmation -> 2
        state.taskId != null || state.processingTurn || state.clarificationSteps.isNotEmpty() -> 1
        else -> 1
    }
}

internal fun sfRealFlowProgressSignature(state: Index9AssistantUiState?): String {
    if (state == null) return ""
    return state.clarificationSteps.joinToString("|") { step ->
        val batch = step.batchCallResult
        val batchItems = batch?.items.orEmpty().joinToString(",") { item ->
            listOf(
                item.itemId,
                item.targetName,
                item.status,
                item.headline,
                item.attemptCount.toString(),
                item.recalled.toString()
            ).joinToString(":")
        }
        listOf(
            step.text.hashCode().toString(),
            step.thinking.orEmpty().hashCode().toString(),
            step.callStatusEvents.joinToString("\n").hashCode().toString(),
            batch?.status.orEmpty(),
            batch?.headline.orEmpty().hashCode().toString(),
            batchItems.hashCode().toString()
        ).joinToString("#")
    }
}

internal fun sfLooksLikeFinishedCallStatus(status: String): Boolean {
    return looksLikeTerminalCallResultStatus(status)
}

internal fun sfLooksLikeCallResultSummaryLine(text: String): Boolean {
    val trimmed = text.trim()
    return trimmed.startsWith("预订结果：") ||
        trimmed.startsWith("预订结果:") ||
        trimmed.startsWith("AI代打结果：") ||
        trimmed.startsWith("AI代打结果:")
}

internal fun sfHasVisibleCallDialogue(data: CallPageData): Boolean {
    return data.transcript.any {
        it.role != TranscriptRole.Note && !sfLooksLikeCallResultSummaryLine(it.text)
    }
}
