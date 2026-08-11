package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.AgentChatResponse
import com.vvtech.aiassistant.core.model.OptionItem
import com.vvtech.aiassistant.core.model.OptionsPayload
import com.vvtech.aiassistant.features.assistant.AssistantStage
import com.vvtech.aiassistant.features.assistant.ClarificationStep
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.VoiceRole
import com.vvtech.aiassistant.features.assistant_timeline.ShowOptionsDisplayTextFormatter

internal data class AgentStreamInteractiveResponsePlan(
    val nextState: Index9AssistantUiState,
    val voicePrompt: String? = null,
    val assistantStepText: String? = null
)

internal object AgentStreamInteractiveResponsePolicy {
    fun plan(
        state: Index9AssistantUiState,
        response: AgentChatResponse,
        voiceMode: Boolean
    ): AgentStreamInteractiveResponsePlan? {
        return when (response.type) {
            TYPE_ASK_USER -> askUser(state, response, voiceMode)
            TYPE_SHOW_OPTIONS -> showOptions(state, response, voiceMode)
            TYPE_REQUEST_PERMISSION -> requestPermission(state, response, voiceMode)
            TYPE_IMPORT_DOCUMENT_REQUEST -> importDocumentRequest(state, response, voiceMode)
            else -> null
        }
    }

    fun optionsVoiceSummary(options: OptionsPayload?): String {
        val items = options?.items.orEmpty()
        if (items.isEmpty()) return ""
        val unit = if (items.any { it.looksLikePlaceCandidate() }) "家" else "个"
        return items.mapIndexed { index, item ->
            "第${voiceOrdinal(index + 1)}$unit，${item.voiceOptionLabel()}"
        }.joinToString("。")
    }

    private fun askUser(
        state: Index9AssistantUiState,
        response: AgentChatResponse,
        voiceMode: Boolean
    ): AgentStreamInteractiveResponsePlan {
        val questionItems = response.questions?.items.orEmpty()
        val questions = questionItems.joinToString("，") { it.prompt }
        val title = response.questions?.title?.takeIf { it.isNotBlank() } ?: "再确认几件事"
        if (voiceMode) {
            val voicePrompt = if (questionItems.size == 1) {
                questionItems.first().prompt.trim().ifBlank { title }
            } else {
                "$title：$questions"
            }
            val assistantStepText =
                "$title\n${response.questions?.items?.joinToString("\n") { "· ${it.prompt}" }.orEmpty()}"
            return AgentStreamInteractiveResponsePlan(
                nextState = state.copy(
                    stage = AssistantStage.Clarifying,
                    processingTurn = false,
                    loading = false,
                    error = null,
                    status = "请语音回答",
                    agentOptions = null,
                    agentQuestions = null,
                    agentPermissionRequest = null,
                    agentDocumentRequest = null,
                    agentDocumentImporting = false,
                    agentPendingToolCallId = response.pendingToolCallId
                ).withVoiceInteractiveAssistantStep(assistantStepText),
                voicePrompt = voicePrompt,
                assistantStepText = assistantStepText
            )
        }
        return AgentStreamInteractiveResponsePlan(
            nextState = state.copy(
                stage = AssistantStage.Clarifying,
                processingTurn = false,
                loading = false,
                error = null,
                status = response.questions?.title?.takeIf { it.isNotBlank() } ?: "AI在确认细节",
                agentQuestions = response.questions,
                agentOptions = null,
                agentPermissionRequest = null,
                agentDocumentRequest = null,
                agentDocumentImporting = false,
                agentPendingToolCallId = response.pendingToolCallId
            )
        )
    }

    private fun showOptions(
        state: Index9AssistantUiState,
        response: AgentChatResponse,
        voiceMode: Boolean
    ): AgentStreamInteractiveResponsePlan {
        val title = response.options?.title ?: "请选择"
        if (voiceMode) {
            val optionsText = response.options
                ?.let(ShowOptionsDisplayTextFormatter::format)
                ?: title
            return AgentStreamInteractiveResponsePlan(
                nextState = state.copy(
                    stage = AssistantStage.Clarifying,
                    processingTurn = false,
                    loading = false,
                    error = null,
                    status = title,
                    agentOptions = response.options,
                    agentQuestions = null,
                    agentPermissionRequest = null,
                    agentDocumentRequest = null,
                    agentDocumentImporting = false,
                    agentPendingToolCallId = response.pendingToolCallId
                ).withVoiceInteractiveAssistantStep(optionsText),
                voicePrompt = "$title。${optionsVoiceSummary(response.options)}",
                assistantStepText = optionsText
            )
        }
        return AgentStreamInteractiveResponsePlan(
            nextState = state.copy(
                stage = AssistantStage.Clarifying,
                processingTurn = false,
                loading = false,
                error = null,
                status = title,
                agentOptions = response.options,
                agentQuestions = null,
                agentPermissionRequest = null,
                agentDocumentRequest = null,
                agentDocumentImporting = false,
                agentPendingToolCallId = response.pendingToolCallId
            )
        )
    }

    private fun requestPermission(
        state: Index9AssistantUiState,
        response: AgentChatResponse,
        voiceMode: Boolean
    ): AgentStreamInteractiveResponsePlan {
        val request = response.permissionRequest
        val reason = request?.reason?.takeIf { it.isNotBlank() } ?: "需要你授权后才能继续"
        return AgentStreamInteractiveResponsePlan(
            nextState = state.copy(
                stage = AssistantStage.Clarifying,
                processingTurn = false,
                loading = false,
                error = null,
                status = reason,
                agentOptions = null,
                agentQuestions = null,
                agentPermissionRequest = request,
                agentDocumentRequest = null,
                agentDocumentImporting = false,
                agentPendingToolCallId = response.pendingToolCallId
            ).let {
                if (voiceMode) it.withVoiceInteractiveAssistantStep(reason) else it
            },
            voicePrompt = reason.takeIf { voiceMode },
            assistantStepText = reason.takeIf { voiceMode }
        )
    }

    private fun importDocumentRequest(
        state: Index9AssistantUiState,
        response: AgentChatResponse,
        voiceMode: Boolean
    ): AgentStreamInteractiveResponsePlan {
        val request = response.documentImportRequest
        val reason = request?.reason?.takeIf { it.isNotBlank() } ?: "请上传 Markdown 或 TXT 文档"
        return AgentStreamInteractiveResponsePlan(
            nextState = state.copy(
                stage = AssistantStage.Clarifying,
                processingTurn = false,
                loading = false,
                error = null,
                status = reason,
                agentOptions = null,
                agentQuestions = null,
                agentPermissionRequest = null,
                agentDocumentRequest = request,
                agentDocumentImporting = false,
                agentPendingToolCallId = response.pendingToolCallId
            ).let {
                if (voiceMode) it.withVoiceInteractiveAssistantStep(reason) else it
            },
            voicePrompt = reason.takeIf { voiceMode },
            assistantStepText = reason.takeIf { voiceMode }
        )
    }

    private fun OptionItem.looksLikePlaceCandidate(): Boolean {
        val normalizedTags = tags.orEmpty().joinToString("|").lowercase()
        return !address.isNullOrBlank() ||
            distanceMeters != null ||
            normalizedTags.contains("restaurant") ||
            normalizedTags.contains("store") ||
            normalizedTags.contains("merchant") ||
            normalizedTags.contains("餐厅") ||
            normalizedTags.contains("门店") ||
            normalizedTags.contains("商家")
    }

    private fun OptionItem.voiceOptionLabel(): String {
        val isContact = tags.orEmpty().any { it.equals("contact", ignoreCase = true) }
        val phoneText = phone?.trim()?.takeIf { it.isNotBlank() }
        return if (isContact && phoneText != null) "$label，$phoneText" else label
    }

    private fun voiceOrdinal(index: Int): String {
        return when (index) {
            1 -> "一"
            2 -> "二"
            3 -> "三"
            4 -> "四"
            5 -> "五"
            6 -> "六"
            7 -> "七"
            8 -> "八"
            9 -> "九"
            10 -> "十"
            else -> index.toString()
        }
    }

    private fun Index9AssistantUiState.withVoiceInteractiveAssistantStep(
        assistantStepText: String
    ): Index9AssistantUiState {
        val prompt = assistantStepText.trim()
        if (prompt.isBlank()) return this
        return copy(
            clarificationSteps = clarificationSteps.withVoiceInteractiveAssistantStep(prompt)
        )
    }

    private fun List<ClarificationStep>.withVoiceInteractiveAssistantStep(
        assistantStepText: String
    ): List<ClarificationStep> {
        val last = lastOrNull()
        if (last?.role != VoiceRole.Assistant) {
            return this + ClarificationStep(
                role = VoiceRole.Assistant,
                text = assistantStepText,
                status = ""
            )
        }
        if (last.text.trim() == assistantStepText) return this
        val shouldReplace = last.text.isBlank() ||
            last.toolCards.isNotEmpty() ||
            !last.toolCalls.isNullOrEmpty() ||
            last.partialToolCalls.isNotEmpty() ||
            last.text.trim() in GenericInteractiveAssistantTexts
        if (!shouldReplace) {
            return this + ClarificationStep(
                role = VoiceRole.Assistant,
                text = assistantStepText,
                status = ""
            )
        }
        return dropLast(1) + last.copy(text = assistantStepText)
    }

    private val GenericInteractiveAssistantTexts = setOf(
        "需要你补充信息",
        "需要你补充信息。",
        "请补充信息",
        "请补充必要信息",
        "请语音回答"
    )

    private const val TYPE_ASK_USER = "ASK_USER"
    private const val TYPE_SHOW_OPTIONS = "SHOW_OPTIONS"
    private const val TYPE_REQUEST_PERMISSION = "REQUEST_PERMISSION"
    private const val TYPE_IMPORT_DOCUMENT_REQUEST = "IMPORT_DOCUMENT_REQUEST"
}
