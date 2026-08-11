package com.vvtech.aiassistant.features.assistant_session

import com.vvtech.aiassistant.core.model.DetailSupplementPromptResponse
import com.vvtech.aiassistant.core.model.DetailSupplementQuestionResponse
import com.vvtech.aiassistant.features.assistant.SummaryData
import com.vvtech.aiassistant.features.assistant.VoiceLanguage

internal object AssistantSessionDetailSupplementPolicy {
    fun shouldEnterDetailSupplement(
        sceneType: String,
        taskId: String,
        hasActionable: Boolean,
        completedTaskId: String?
    ): Boolean {
        if (!hasActionable) return false
        if (sceneType !in detailSupplementScenes) return false
        if (completedTaskId == taskId) return false
        return true
    }

    fun shouldForceSelectionDetailSupplement(
        sceneType: String,
        hasActionable: Boolean,
        hasSelectionSheet: Boolean,
        selectionContinuationSceneType: String?
    ): Boolean {
        if (selectionContinuationSceneType == null) return false
        if (sceneType !in selectionDrivenDetailSupplementScenes) return false
        if (hasSelectionSheet || hasActionable) return false
        return selectionContinuationSceneType == sceneType
    }

    fun decorateSummaryWithSupplement(
        taskId: String,
        summary: SummaryData,
        contactTaskId: String?,
        contactValue: String?,
        detailTaskId: String?,
        detailValue: String?,
        contactLabel: String,
        detailLabel: String
    ): SummaryData {
        val matchedContactValue = contactValue.takeIf { contactTaskId == taskId }
        val matchedDetailValue = detailValue.takeIf { detailTaskId == taskId }
        return summary.copy(
            contactLabel = matchedContactValue?.let { contactLabel } ?: summary.contactLabel,
            contactValue = matchedContactValue ?: summary.contactValue,
            detailLabel = matchedDetailValue?.let { detailLabel } ?: summary.detailLabel,
            detailValue = matchedDetailValue ?: summary.detailValue
        )
    }

    fun localizedPromptResponse(
        language: VoiceLanguage,
        sceneType: String,
        title: String,
        promptResponse: DetailSupplementPromptResponse
    ): DetailSupplementPromptResponse {
        if (language == VoiceLanguage.Chinese) {
            return promptResponse
        }
        return DetailSupplementPromptResponse(
            sceneType = sceneType,
            title = title,
            intro = detailIntro(language, sceneType),
            questions = localizedDetailQuestions(language, sceneType)
        )
    }

    fun detailIntro(language: VoiceLanguage, sceneType: String): String = when (language) {
        VoiceLanguage.English -> when (sceneType) {
            "HOTEL_BOOKING" -> "Confirm the booking contact first, then add hotel preferences or skip them."
            else -> "Confirm the booking contact first, then add restaurant preferences or skip them."
        }
        VoiceLanguage.Japanese -> when (sceneType) {
            "HOTEL_BOOKING" -> "先に予約者情報を確認し、その後でホテルの追加条件を指定するかスキップできます。"
            else -> "先に予約者情報を確認し、その後でレストランの追加条件を指定するかスキップできます。"
        }
        VoiceLanguage.Chinese -> "先确认预订人信息，之后你可以跳过或继续补充偏好。"
    }

    fun localizedDetailQuestions(
        language: VoiceLanguage,
        sceneType: String
    ): List<DetailSupplementQuestionResponse> {
        return when (language) {
            VoiceLanguage.English -> when (sceneType) {
                "HOTEL_BOOKING" -> listOf(
                    DetailSupplementQuestionResponse("nonSmoking", "Do you need a non-smoking room?"),
                    DetailSupplementQuestionResponse("quietHighFloor", "Do you prefer a quiet high-floor room?"),
                    DetailSupplementQuestionResponse("parking", "Do you need parking?")
                )
                else -> listOf(
                    DetailSupplementQuestionResponse("needPrivateRoom", "Do you need a private room?"),
                    DetailSupplementQuestionResponse("askMinimumSpend", "Should I ask about the private room minimum spend?"),
                    DetailSupplementQuestionResponse("allowHallFallback", "If no private room is available, can I book the main dining hall?")
                )
            }
            VoiceLanguage.Japanese -> when (sceneType) {
                "HOTEL_BOOKING" -> listOf(
                    DetailSupplementQuestionResponse("nonSmoking", "禁煙ルームを希望しますか？"),
                    DetailSupplementQuestionResponse("quietHighFloor", "静かな高層階の部屋を希望しますか？"),
                    DetailSupplementQuestionResponse("parking", "駐車場は必要ですか？")
                )
                else -> listOf(
                    DetailSupplementQuestionResponse("needPrivateRoom", "個室を希望しますか？"),
                    DetailSupplementQuestionResponse("askMinimumSpend", "個室の最低利用金額を確認しますか？"),
                    DetailSupplementQuestionResponse("allowHallFallback", "個室がない場合、通常席で予約してもよいですか？")
                )
            }
            VoiceLanguage.Chinese -> emptyList()
        }
    }

    private val detailSupplementScenes = setOf("FOOD_ORDERING", "HOTEL_BOOKING", "FLIGHT_BOOKING")
    private val selectionDrivenDetailSupplementScenes = setOf("FOOD_ORDERING", "HOTEL_BOOKING")
}
