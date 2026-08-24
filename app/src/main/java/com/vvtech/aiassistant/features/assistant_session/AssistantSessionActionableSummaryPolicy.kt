package com.vvtech.aiassistant.features.assistant_session

import com.vvtech.aiassistant.core.model.AssistantSessionResponse
import com.vvtech.aiassistant.features.assistant.CallPageData
import com.vvtech.aiassistant.features.assistant.SummaryData
import com.vvtech.aiassistant.features.assistant.TranscriptLine
import com.vvtech.aiassistant.features.assistant.TranscriptRole
import com.vvtech.aiassistant.features.assistant.VoiceLanguage
import com.vvtech.aiassistant.features.assistant.sanitizeUserFacingNetworkText
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText

internal object AssistantSessionActionableSummaryPolicy {
    data class BuildContext(
        val language: VoiceLanguage,
        val contactTaskId: String?,
        val contactValue: String?,
        val detailTaskId: String?,
        val detailValue: String?,
        val contactLabel: String,
        val detailLabel: String,
        val defaultConfirmLabel: String
    )

    fun resolve(
        session: AssistantSessionResponse,
        context: BuildContext
    ): AssistantSessionActionableSummary? {
        val card = session.messages.lastOrNull { it.callConfirmCard != null }?.callConfirmCard
            ?: return null
        val primary = card.actions.firstOrNull { it.kind == "primary" } ?: card.actions.firstOrNull()
        val localizeNonChinese = context.language != VoiceLanguage.Chinese
        val localizeBookingScene = localizeNonChinese &&
            session.session.sceneType in bookingSceneTypes
        val taskTitle = sanitizeActionableSummaryText(
            session.session.title.ifBlank { sceneLabel(session.session.sceneType) },
            context.language
        )
        val targetName = sanitizeActionableSummaryText(card.targetName, context.language)
        val purpose = sanitizeActionableSummaryText(card.purpose, context.language)
        val cardSummary = sanitizeActionableSummaryText(card.summary, context.language)
        val summary = SummaryData(
            task = taskTitle,
            targetLabel = if (localizeNonChinese) targetLabel(context.language) else "对象",
            target = targetName.ifBlank {
                if (localizeNonChinese) pendingTarget(context.language) else "待联系对象"
            },
            timeLabel = if (localizeNonChinese) phoneLabel(context.language) else "电话",
            time = card.phone?.takeIf { it.isNotBlank() }
                ?: if (localizeNonChinese) pendingValue(context.language) else "待确认",
            extraLabel = if (localizeNonChinese) detailsLabel(context.language) else "重点",
            extra = purpose.ifBlank { cardSummary }
        )
        return AssistantSessionActionableSummary(
            summary = AssistantSessionDetailSupplementPolicy.decorateSummaryWithSupplement(
                taskId = session.session.taskId,
                summary = summary,
                contactTaskId = context.contactTaskId,
                contactValue = context.contactValue,
                detailTaskId = context.detailTaskId,
                detailValue = context.detailValue,
                contactLabel = context.contactLabel,
                detailLabel = context.detailLabel
            ),
            confirmLabel = sanitizeActionableSummaryText(primary?.label ?: context.defaultConfirmLabel, context.language),
            primaryAction = primary,
            callPageSeed = CallPageData(
                name = targetName.ifBlank { taskTitle },
                sub = card.phone?.takeIf { it.isNotBlank() }
                    ?: sanitizeActionableSummaryText(sceneLabel(session.session.sceneType), context.language),
                status = if (localizeNonChinese) readyToCallStatus(context.language) else "准备发起电话",
                transcript = buildList {
                    if (purpose.isNotBlank()) {
                        add(
                            TranscriptLine(
                                TranscriptRole.Note,
                                if (localizeNonChinese) callFocus(context.language, purpose)
                                else "通话重点：${card.purpose}"
                            )
                        )
                    }
                    add(TranscriptLine(TranscriptRole.Assistant, cardSummary))
                }
            )
        )
    }

    private fun sceneLabel(sceneType: String): String {
        return when (sceneType) {
            "FOOD_ORDERING" -> currentAppText("订餐任务", "Restaurant Booking")
            "HOTEL_BOOKING" -> currentAppText("订酒店", "Hotel Booking")
            "FLIGHT_BOOKING" -> currentAppText("订机票", "Flight Booking")
            "AI_CALL" -> currentAppText("帮打电话", "AI Call")
            else -> currentAppText("AI 任务", "AI Task")
        }
    }

    private fun targetLabel(language: VoiceLanguage): String = when (language) {
        VoiceLanguage.English -> "Target"
        VoiceLanguage.Japanese -> "対象"
        VoiceLanguage.Chinese -> "对象"
    }

    private fun pendingTarget(language: VoiceLanguage): String = when (language) {
        VoiceLanguage.English -> "Pending target"
        VoiceLanguage.Japanese -> "対象未確認"
        VoiceLanguage.Chinese -> "待联系对象"
    }

    private fun phoneLabel(language: VoiceLanguage): String = when (language) {
        VoiceLanguage.English -> "Phone"
        VoiceLanguage.Japanese -> "電話"
        VoiceLanguage.Chinese -> "电话"
    }

    private fun pendingValue(language: VoiceLanguage): String = when (language) {
        VoiceLanguage.English -> "Pending"
        VoiceLanguage.Japanese -> "未確認"
        VoiceLanguage.Chinese -> "待确认"
    }

    private fun detailsLabel(language: VoiceLanguage): String = when (language) {
        VoiceLanguage.English -> "Details"
        VoiceLanguage.Japanese -> "要点"
        VoiceLanguage.Chinese -> "重点"
    }

    private fun readyToCallStatus(language: VoiceLanguage): String = when (language) {
        VoiceLanguage.English -> "Ready to call"
        VoiceLanguage.Japanese -> "発信準備完了"
        VoiceLanguage.Chinese -> "准备发起电话"
    }

    private fun callFocus(language: VoiceLanguage, purpose: String): String = when (language) {
        VoiceLanguage.English -> "Call focus: $purpose"
        VoiceLanguage.Japanese -> "通話の要点：$purpose"
        VoiceLanguage.Chinese -> "通话重点：$purpose"
    }

    private fun sanitizeActionableSummaryText(value: String, language: VoiceLanguage): String {
        return if (language == VoiceLanguage.English) {
            sanitizeUserFacingNetworkText(value, language)
        } else {
            value
        }
    }

    private val bookingSceneTypes = setOf("FOOD_ORDERING", "HOTEL_BOOKING")
}
