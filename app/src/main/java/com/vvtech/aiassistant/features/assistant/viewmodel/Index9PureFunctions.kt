package com.vvtech.aiassistant.features.assistant.viewmodel

import com.vvtech.aiassistant.features.assistant.*

import com.vvtech.aiassistant.core.model.AssistantMessageItem
import com.vvtech.aiassistant.core.model.AssistantSessionResponse
import com.vvtech.aiassistant.core.model.CallSessionStatusResponse
import com.vvtech.aiassistant.core.model.ResultSummaryPayload
import com.vvtech.aiassistant.core.model.VoiceDialogContextResponse
import com.vvtech.aiassistant.domain.task.isSuccessfulTerminalTaskExecutionStatus
import com.vvtech.aiassistant.model.TaskListItem
import com.vvtech.aiassistant.features.assistant.AssistantStage
import com.vvtech.aiassistant.features.assistant.CallPageData
import com.vvtech.aiassistant.features.assistant.ClarificationStep
import com.vvtech.aiassistant.features.assistant.EffectiveTaskContact
import com.vvtech.aiassistant.features.assistant.HistoryRecord
import com.vvtech.aiassistant.features.assistant.PersonalInfoGender
import com.vvtech.aiassistant.features.assistant.SelectionSheetData
import com.vvtech.aiassistant.features.assistant.SelectionSheetOption
import com.vvtech.aiassistant.features.assistant.StatusStyle
import com.vvtech.aiassistant.features.assistant.SummaryData
import com.vvtech.aiassistant.features.assistant.TranscriptLine
import com.vvtech.aiassistant.features.assistant.TranscriptRole
import com.vvtech.aiassistant.features.assistant.VoiceLanguage
import com.vvtech.aiassistant.features.assistant.VoiceRole
import com.vvtech.aiassistant.features.assistant_session.AssistantSessionDialogueStepPolicy
import com.vvtech.aiassistant.features.assistant_session.AssistantSessionSelectionSheetPolicy
import com.vvtech.aiassistant.features.assistant_tasks.TaskHistoryStatusStyle
import com.vvtech.aiassistant.features.assistant_tasks.buildTaskCallHistoryMetaDetail
import com.vvtech.aiassistant.features.assistant_tasks.buildTaskHistoryRecordDisplay
import com.vvtech.aiassistant.features.assistant_tasks.buildTaskResultSummaryStatus
import com.vvtech.aiassistant.features.assistant_tasks.parseTaskCallDialogueDetail
import com.vvtech.aiassistant.features.assistant_tasks.parseTaskCallSessionUpdatedAt
import com.vvtech.aiassistant.features.assistant_tasks.normalizeTaskHistoryMeta
import com.vvtech.aiassistant.features.assistant_tasks.sameTaskCallSessionTranscriptLine
import com.vvtech.aiassistant.features.assistant_tasks.summarizeTaskHistoryMeta
import com.vvtech.aiassistant.features.assistant_tasks.taskCallSessionIsStreamingDialogueLine
import com.vvtech.aiassistant.features.assistant_tasks.taskHistorySortKey
import java.time.LocalDateTime

/**
 * 一组从 [com.vvtech.aiassistant.features.assistant.AssistantViewModel] 拆出来的纯函数。
 *
 * 选择标准：函数体内仅依赖入参 + 顶层常量，**不读写 ViewModel 状态**。
 * 命名 / 行为 / 边界条件全部保持原样，仅做位置搬迁与可见性调整为 internal。
 */

// ---------- 文本预处理 / 中文数字 ----------

private const val SpokenPhoneDigitChars = "零〇一二两三四五六七八九十壹贰叁肆伍陆柒捌玖拾幺\\d"

internal fun shouldSuppressDialogAudioForCall(
    showAiCallPage: Boolean,
    pendingAiCallLaunch: Boolean,
    outboundCallAudioSuppressed: Boolean = false,
    currentCallId: String? = null
): Boolean = showAiCallPage ||
    pendingAiCallLaunch ||
    outboundCallAudioSuppressed ||
    !currentCallId.isNullOrBlank()

private val SpokenPhoneContextPattern = Regex(
    "((?:手机号码|手机号|手机|联系电话|电话|号码|联系方式|联系号码|预留电话|预留号码|尾号|后四位|后3位|后4位|后三位|后面四位|末四位)" +
        "\\s*(?:是|为|叫|：|:)?\\s*)((?:[$SpokenPhoneDigitChars][\\s、,，.。\\-－]*){2,20})"
)

internal fun replaceChineseDigits(text: String): String {
    val phonePattern =
        Regex("([$SpokenPhoneDigitChars]\\s*){7,}")
    val timeNumberChars = "零〇一二两三四五六七八九十壹贰叁肆伍陆柒捌玖拾"
    val timePattern =
        Regex("([$timeNumberChars\\d]{1,3})\\s*点\\s*(半|([$timeNumberChars\\d]{1,3})\\s*分?)?")

    var result = text
    result = result.replace(SpokenPhoneContextPattern) { match ->
        val prefix = match.groupValues[1]
        val token = match.groupValues[2]
        val trailingSeparators = token.takeLastWhile { it.isSpokenPhoneDigitSeparator() }
        val coreToken = token.dropLast(trailingSeparators.length)
        val normalizedDigits = normalizeSpokenPhoneDigits(coreToken)
        if (normalizedDigits.isBlank()) {
            match.value
        } else {
            prefix + normalizedDigits + trailingSeparators
        }
    }
    result = result.replace(phonePattern) { match ->
        if (match.value.any { it.isSpokenPhoneDigit() }) {
            normalizeSpokenPhoneDigits(match.value)
        } else {
            match.value
        }
    }
    result = result.replace(timePattern) { match ->
        val hourToken = match.groupValues[1]
        val minuteSuffix = match.groupValues[2]
        val minuteToken = match.groupValues[3]
        val nextChar = result.getOrNull(match.range.last + 1)
        val allowMergedHourCorrection = nextChar != '位' && nextChar != '评'
        buildString {
            append(normalizeTimeNumberToken(hourToken, isHour = true, allowMergedHourCorrection))
            append("点")
            when {
                minuteSuffix == "半" -> append("半")
                minuteToken.isNotBlank() -> {
                    append(normalizeTimeNumberToken(minuteToken, isHour = false))
                    if (minuteSuffix.contains("分")) {
                        append("分")
                    }
                }
            }
        }
    }
    return result
}

private fun normalizeSpokenPhoneDigits(token: String): String {
    return buildString {
        token.forEach { ch ->
            when {
                ch.isDigit() -> append(ch)
                ch.isSpokenPhoneDigit() -> append(convertChineseDigitChar(ch))
            }
        }
    }
}

private fun Char.isSpokenPhoneDigit(): Boolean {
    return this in listOf(
        '零', '〇', '一', '二', '两', '三', '四', '五', '六', '七', '八', '九', '十',
        '壹', '贰', '叁', '肆', '伍', '陆', '柒', '捌', '玖', '拾', '幺'
    )
}

private fun Char.isSpokenPhoneDigitSeparator(): Boolean {
    return isWhitespace() || this in listOf('、', ',', '，', '.', '。', '-', '－')
}

private fun normalizeTimeNumberToken(
    token: String,
    isHour: Boolean,
    allowMergedHourCorrection: Boolean = true
): String {
    val compact = token.filterNot { it.isWhitespace() }
    if (compact.isBlank()) return compact
    if (isHour && allowMergedHourCorrection) {
        normalizeMergedAsrHour(compact)?.let { return it }
    }
    parseChineseTimeNumberToken(compact)?.let { return it }
    return compact.map { ch -> convertChineseDigitChar(ch) }.joinToString("")
}

private fun normalizeMergedAsrHour(token: String): String? {
    if (token.length != 3 || !token.startsWith("10")) return null
    val ones = token[2]
    if (ones !in '1'..'9') return null
    return (10 + (ones - '0')).toString()
}

private fun parseChineseTimeNumberToken(token: String): String? {
    val normalized = token.map { ch -> if (ch == '拾') '十' else ch }.joinToString("")
    val tenIndex = normalized.indexOf('十')
    if (tenIndex >= 0) {
        val tensToken = normalized.substring(0, tenIndex)
        val onesToken = normalized.substring(tenIndex + 1)
        val tens = when {
            tensToken.isBlank() -> 1
            tensToken.length == 1 -> timeDigitValue(tensToken[0]) ?: return null
            else -> return null
        }
        val ones = when {
            onesToken.isBlank() -> 0
            onesToken.length == 1 -> timeDigitValue(onesToken[0]) ?: return null
            else -> return null
        }
        return (tens * 10 + ones).toString()
    }
    val digits = normalized.map { ch -> timeDigitValue(ch) ?: return null }
    return digits.joinToString("")
}

private fun timeDigitValue(ch: Char): Int? {
    if (ch in '0'..'9') return ch - '0'
    return when (ch) {
        '零', '〇' -> 0
        '一', '壹' -> 1
        '二', '两', '贰' -> 2
        '三', '叁' -> 3
        '四', '肆' -> 4
        '五', '伍' -> 5
        '六', '陆' -> 6
        '七', '柒' -> 7
        '八', '捌' -> 8
        '九', '玖' -> 9
        else -> null
    }
}

internal fun convertChineseDigitChar(ch: Char): String {
    return when (ch) {
        '零', '〇' -> "0"
        '一', '幺', '壹' -> "1"
        '二', '两', '贰' -> "2"
        '三', '叁' -> "3"
        '四', '肆' -> "4"
        '五', '伍' -> "5"
        '六', '陆' -> "6"
        '七', '柒' -> "7"
        '八', '捌' -> "8"
        '九', '玖' -> "9"
        '十', '拾' -> "10"
        else -> ch.toString()
    }
}

internal fun looksLikeDateOnlyHotelAnswer(text: String): Boolean {
    val normalized = text.trim()
    if (normalized.isBlank()) return false
    return normalized == "今天" ||
        normalized == "今晚" ||
        normalized == "明天" ||
        normalized == "明晚" ||
        normalized == "后天" ||
        normalized == "大后天" ||
        normalized.endsWith("号") ||
        normalized.endsWith("日") ||
        normalized.endsWith("天")
}

// ---------- 场景检测 / 状态判断 ----------

internal fun detectLocalSceneHint(utterance: String): String {
    val source = utterance.trim()
    if (source.isBlank()) return "GENERAL"
    if (matchesSceneHint(source, LocalFlightSceneHints)) return "FLIGHT_BOOKING"
    if (matchesSceneHint(source, LocalHotelSceneHints)) return "HOTEL_BOOKING"
    if (matchesSceneHint(source, LocalCallSceneHints)) return "AI_CALL"
    if (matchesSceneHint(source, LocalFoodSceneHints)) return "FOOD_ORDERING"
    return "GENERAL"
}

private fun matchesSceneHint(source: String, hints: List<String>): Boolean {
    val lowerSource = source.lowercase()
    return hints.any { hint ->
        source.contains(hint) || lowerSource.contains(hint.lowercase())
    }
}

internal fun isBackendStateMachineScene(sceneType: String?): Boolean {
    return sceneType != null && sceneType in BackendStateMachineScenes
}

internal fun isTerminalTaskStatus(taskStatus: String?): Boolean {
    return isSuccessfulTerminalTaskExecutionStatus(taskStatus)
}

internal fun isTerminalTask(item: TaskListItem): Boolean {
    return isSuccessfulTerminalTaskExecutionStatus(item.status)
}

internal fun textProcessingStatusLabel(sceneType: String): String = when (sceneType) {
    "FOOD_ORDERING" -> "查询餐厅中"
    "HOTEL_BOOKING" -> "查询酒店中"
    else -> "AI处理中"
}

internal fun sceneLabel(sceneType: String): String {
    return when (sceneType) {
        "FOOD_ORDERING" -> "订餐任务"
        "HOTEL_BOOKING" -> "订酒店"
        "FLIGHT_BOOKING" -> "订机票"
        "AI_CALL" -> "帮打电话"
        else -> "AI 任务"
    }
}

internal fun maxStage(current: AssistantStage, target: AssistantStage): AssistantStage {
    val order = listOf(AssistantStage.Idle, AssistantStage.Clarifying, AssistantStage.Recognized)
    return if (order.indexOf(target) > order.indexOf(current)) target else current
}

// ---------- transcript 解析 ----------

internal fun parseCallSessionUpdatedAt(value: String?): LocalDateTime? {
    return parseTaskCallSessionUpdatedAt(value)
}

internal fun parseCallDialogueDetail(detail: String): List<TranscriptLine> {
    return parseTaskCallDialogueDetail(detail)
}

internal fun isStreamingDialogueLine(line: TranscriptLine): Boolean {
    return taskCallSessionIsStreamingDialogueLine(line)
}

internal fun sameTranscriptLine(left: TranscriptLine, right: TranscriptLine): Boolean {
    return sameTaskCallSessionTranscriptLine(left, right)
}

internal fun previewText(text: String?, limit: Int = 48): String {
    val normalized = text?.trim().orEmpty().replace('\n', ' ')
    return if (normalized.length <= limit) normalized else normalized.take(limit) + "..."
}

// ---------- assistant 消息解析 / clarification 步骤 ----------

internal fun mapClarificationSteps(
    messages: List<AssistantMessageItem>,
    hideInternalSync: Boolean = false
): List<ClarificationStep> = AssistantSessionDialogueStepPolicy.mapClarificationSteps(
    messages = messages,
    hideInternalSync = hideInternalSync
)

internal fun extractVisibleAssistantDialogueText(message: AssistantMessageItem): String? {
    return AssistantSessionDialogueStepPolicy.extractVisibleAssistantDialogueText(message)
}

internal fun normalizeAssistantDialogueText(text: String?): String {
    return AssistantSessionDialogueStepPolicy.normalizeAssistantDialogueText(text)
}

internal fun resolveLatestBackendAssistantPrompt(
    currentSteps: List<ClarificationStep>,
    backendSteps: List<ClarificationStep>
): String? {
    return AssistantSessionDialogueStepPolicy.resolveLatestBackendAssistantPrompt(currentSteps, backendSteps)
}

internal fun removeTrailingAssistantPrompt(
    steps: List<ClarificationStep>,
    prompt: String?
): List<ClarificationStep> {
    return AssistantSessionDialogueStepPolicy.removeTrailingAssistantPrompt(steps, prompt)
}

internal fun appendClarificationStepIfMissing(
    steps: MutableList<ClarificationStep>,
    role: VoiceRole,
    text: String
) {
    AssistantSessionDialogueStepPolicy.appendClarificationStepIfMissing(steps, role, text)
}

// ---------- selection sheet ----------

internal fun buildSelectionMeta(tags: List<String>, address: String?): String =
    AssistantSessionSelectionSheetPolicy.buildSelectionMeta(tags, address)

internal fun resolveVoiceSelectionOption(text: String, sheet: SelectionSheetData): SelectionSheetOption? {
    return AssistantSessionSelectionSheetPolicy.resolveVoiceSelectionOption(text, sheet)
}

internal fun parseVoiceSelectionIndex(text: String, optionCount: Int): Int? {
    return AssistantSessionSelectionSheetPolicy.parseVoiceSelectionIndex(text, optionCount)
}

internal fun resolveSelectionSheetFromSession(
    session: AssistantSessionResponse,
    language: VoiceLanguage = VoiceLanguage.Chinese
): SelectionSheetData? {
    return AssistantSessionSelectionSheetPolicy.resolveSelectionSheetFromSession(session, language)
}

// ---------- detail supplement ----------

internal fun maskIdCardNumber(value: String): String {
    val normalized = value.trim().uppercase()
    return when {
        normalized.length <= 8 -> normalized
        else -> normalized.take(4) + "*".repeat(normalized.length - 8) + normalized.takeLast(4)
    }
}

internal fun PersonalInfoGender.toDisplayLabel(): String = when (this) {
    PersonalInfoGender.Mr -> "先生"
    PersonalInfoGender.Ms -> "女士"
}

internal fun EffectiveTaskContact.displayName(): String {
    val trimmedName = name.trim()
    if (trimmedName.endsWith("先生") || trimmedName.endsWith("女士")) {
        return trimmedName
    }
    return trimmedName + gender.toDisplayLabel()
}

internal fun buildReservationContactSyncSentence(
    sceneType: String,
    contact: EffectiveTaskContact
): String {
    if (!contact.isComplete(sceneType)) return ""
    return if (sceneType == "FLIGHT_BOOKING") {
        "本次预订请预留信息：${contact.displayName()}，身份证号${contact.idCardNumber}，联系电话${contact.phone}。"
    } else {
        "本次预订请预留信息：${contact.displayName()}，联系电话${contact.phone}。"
    }
}

internal fun buildDetailSupplementSyncSentence(detailSummaryText: String): String {
    if (detailSummaryText.isBlank()) return ""
    return "补充细节：${detailSummaryText.trim()}。"
}

internal fun buildContactSummaryValue(
    sceneType: String,
    contact: EffectiveTaskContact
): String {
    return if (sceneType == "FLIGHT_BOOKING" && contact.idCardNumber.isNotBlank()) {
        "${contact.displayName()}，身份证号${maskIdCardNumber(contact.idCardNumber)}，${contact.phone}"
    } else {
        "${contact.displayName()}，${contact.phone}"
    }
}

internal fun supportsSelectionDrivenDetailSupplement(sceneType: String): Boolean {
    return sceneType in setOf("FOOD_ORDERING", "HOTEL_BOOKING")
}

// ---------- dialog welcome ----------

internal fun resolveDialogWelcomeMessage(context: VoiceDialogContextResponse?): String? {
    val payload = context?.sessionPayload ?: return null
    return (payload["welcome_message"] as? String)
        ?.trim()
        ?.takeIf { it.isNotBlank() }
}

// ---------- history meta 渲染 ----------

internal fun summarizeHistoryMeta(raw: String): String {
    return summarizeTaskHistoryMeta(raw)
}

internal fun normalizePersistedHistoryMeta(meta: String): String {
    return normalizeTaskHistoryMeta(meta)
}

internal fun buildCallHistoryMetaDetail(
    response: CallSessionStatusResponse,
    fallback: String
): String {
    return buildTaskCallHistoryMetaDetail(response, fallback)
}

internal fun taskSortKey(item: TaskListItem): LocalDateTime {
    return taskHistorySortKey(item)
}

internal fun toHistoryRecord(item: TaskListItem): HistoryRecord {
    val display = buildTaskHistoryRecordDisplay(item)
    return HistoryRecord(
        title = display.title,
        status = display.status,
        style = display.style.toStatusStyle(),
        meta = display.meta
    )
}

// ---------- result summary ----------

internal fun buildResultSummaryStatus(result: ResultSummaryPayload): String {
    return buildTaskResultSummaryStatus(result)
}

private fun TaskHistoryStatusStyle.toStatusStyle(): StatusStyle {
    return when (this) {
        TaskHistoryStatusStyle.Success -> StatusStyle.Success
        TaskHistoryStatusStyle.Failure -> StatusStyle.Failure
    }
}

// ---------- callPageSeed 以注/通话调用初始 transcript 不放此处（依赖 ViewModel state）----------

internal fun seedCallPageStatusUpdate(
    seed: CallPageData,
    note: String
): CallPageData = seed.copy(
    status = "正在发起电话...",
    transcript = seed.transcript + TranscriptLine(role = TranscriptRole.Note, text = note)
)
