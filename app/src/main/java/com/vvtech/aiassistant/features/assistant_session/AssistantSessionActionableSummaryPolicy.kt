package com.vvtech.aiassistant.features.assistant_session

import com.vvtech.aiassistant.core.model.AssistantSessionResponse
import com.vvtech.aiassistant.features.assistant.CallPageData
import com.vvtech.aiassistant.features.assistant.SummaryData
import com.vvtech.aiassistant.features.assistant.TranscriptLine
import com.vvtech.aiassistant.features.assistant.TranscriptRole
import com.vvtech.aiassistant.features.assistant.VoiceLanguage

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
        val localizeBookingScene = context.language != VoiceLanguage.Chinese &&
            session.session.sceneType in bookingSceneTypes
        val summary = SummaryData(
            task = session.session.title.ifBlank { sceneLabel(session.session.sceneType) },
            targetLabel = if (localizeBookingScene) targetLabel(context.language) else "对象",
            target = card.targetName.ifBlank {
                if (localizeBookingScene) pendingTarget(context.language) else "待联系对象"
            },
            timeLabel = if (localizeBookingScene) phoneLabel(context.language) else "电话",
            time = card.phone?.takeIf { it.isNotBlank() }
                ?: if (localizeBookingScene) pendingValue(context.language) else "待确认",
            extraLabel = if (localizeBookingScene) detailsLabel(context.language) else "重点",
            extra = card.purpose.ifBlank { card.summary }
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
            confirmLabel = primary?.label ?: context.defaultConfirmLabel,
            primaryAction = primary,
            callPageSeed = CallPageData(
                name = card.targetName.ifBlank { session.session.title },
                sub = card.phone?.takeIf { it.isNotBlank() } ?: sceneLabel(session.session.sceneType),
                status = if (localizeBookingScene) readyToCallStatus(context.language) else "准备发起电话",
                transcript = buildList {
                    if (card.purpose.isNotBlank()) {
                        add(
                            TranscriptLine(
                                TranscriptRole.Note,
                                if (localizeBookingScene) callFocus(context.language, card.purpose)
                                else "通话重点：${card.purpose}"
                            )
                        )
                    }
                    add(TranscriptLine(TranscriptRole.Assistant, card.summary))
                }
            )
        )
    }

    private fun sceneLabel(sceneType: String): String {
        return when (sceneType) {
            "FOOD_ORDERING" -> "订餐任务"
            "HOTEL_BOOKING" -> "订酒店"
            "FLIGHT_BOOKING" -> "订机票"
            "AI_CALL" -> "帮打电话"
            else -> "AI 任务"
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

    private val bookingSceneTypes = setOf("FOOD_ORDERING", "HOTEL_BOOKING")
}
