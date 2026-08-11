package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.features.assistant.TranscriptLine
import com.vvtech.aiassistant.features.assistant.TranscriptRole

/** Keeps durable call-history rendering aligned with the pre-refactor live receipt policy. */
internal fun callHistoryReceiptSummary(
    resultReason: String?,
    statusMessage: String?,
    dialogueSummary: String?,
    transcript: List<TranscriptLine>,
    success: Boolean,
): String {
    listOf(resultReason, statusMessage, dialogueSummary)
        .asSequence()
        .mapNotNull(::meaningfulReceiptText)
        .firstOrNull()
        ?.let { return it }

    transcript
        .asSequence()
        .filter { it.role == TranscriptRole.Assistant }
        .map { compactAssistantIntent(it.text) }
        .firstOrNull { it.isNotBlank() && !it.isLowSignalAssistantLine() }
        ?.let { return it }

    return if (success) "通话已完成" else "外呼未成功"
}

internal fun callHistoryDisplayTitle(targetName: String?, phoneNumber: String?): String {
    val target = targetName.orEmpty().trim()
    val genericTargets = setOf("", "对方", "AI通话", "AI 通话", "目标对象", "未知对象")
    if (target !in genericTargets) return target
    return phoneNumber.orEmpty().trim().ifBlank { "AI通话" }
}

private fun meaningfulReceiptText(raw: String?): String? {
    val fullText = raw.orEmpty()
        .replace('\r', ' ')
        .replace('\n', ' ')
        .replace(Regex("\\s+"), " ")
        .trim()
    val text = compactReceiptText(fullText)
    if (text.isBlank()) return null
    val normalized = text.replace(" ", "").uppercase()
    if (normalized in GENERIC_RECEIPT_TEXTS) return null
    if (ROLE_PREFIX.containsMatchIn(fullText)) return null
    if (fullText.contains("目标号码") && fullText.contains("主叫号码")) {
        val phoneAgentSummary = fullText.substringAfter("电话脑摘要：", "")
            .takeIf { it.isNotBlank() }
            ?.let(::compactReceiptText)
        return phoneAgentSummary?.takeUnless { it.isLowSignalAssistantLine() }
    }
    val cleaned = compactAssistantIntent(fullText)
    return cleaned.takeUnless { it.isLowSignalAssistantLine() }
}

private fun compactReceiptText(raw: String): String {
    val normalized = raw
        .replace('\r', ' ')
        .replace('\n', ' ')
        .replace(Regex("\\s+"), " ")
        .trim()
        .replace(Regex("^(您好|你好|喂)[，,。！!：:\\s]*"), "")
        .trim()
    val firstSentence = normalized
        .split('。', '！', '？', ';', '；')
        .firstOrNull()
        ?.trim()
        .orEmpty()
    return (firstSentence.ifBlank { normalized }).take(42).trim()
}

private fun compactAssistantIntent(raw: String): String {
    var text = raw
        .replace(Regex("电话(是|为)?[：:\\s]*[+\\d\\s-]{7,}"), "")
        .trim(' ', '，', ',', '。')
    val selfIntroductionIndex = listOf("，我是", ",我是", "，我叫", ",我叫")
        .map(text::indexOf)
        .filter { it > 0 }
        .minOrNull()
    if (selfIntroductionIndex != null) {
        text = text.substring(0, selfIntroductionIndex)
    }
    text = text.replace(Regex("^(还是我|又是我)[，,][^，,]{1,16}[，,]"), "")
    return compactReceiptText(text)
}

private fun String.isLowSignalAssistantLine(): Boolean {
    val compact = replace(" ", "")
    if (compact.isBlank()) return true
    if ((compact.contains("请问是") || compact.contains("请问您是")) &&
        (compact.contains("本人") || compact.contains("机主") || compact.contains("对吗"))
    ) {
        return true
    }
    if ((compact.startsWith("还是我") || compact.startsWith("又是我")) &&
        !BUSINESS_SIGNAL.containsMatchIn(compact)
    ) {
        return true
    }
    return compact.length <= 18 && LOW_SIGNAL_ASSISTANT_TEXT.matches(compact)
}

private val ROLE_PREFIX = Regex("(?i)(assistant|callee|merchant|remote|system):")
private val LOW_SIGNAL_ASSISTANT_TEXT = Regex(
    "(嗯|哦|好|好的|行|可以|谢谢|再见|拜拜|先这样|打扰了|收到)([，,。！!]*(嗯|哦|好|好的|行|可以|谢谢))*"
)
private val BUSINESS_SIGNAL = Regex("任务|通知|咨询|询问|预订|预约|转告|提醒|确认|营业|会议|时间")
private val GENERIC_RECEIPT_TEXTS = setOf(
    "AI电话已结束",
    "AI对话已结束",
    "通话已结束",
    "电话已结束",
    "通话已完成",
    "任务已完成",
    "已完成",
    "COMPLETED",
    "SUCCESS",
    "DONE",
    "FINISHED",
)
