package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.AgentChatResponse
import com.vvtech.aiassistant.core.model.AskQuestionsPayload
import com.vvtech.aiassistant.core.model.OptionItem
import com.vvtech.aiassistant.core.model.OptionsPayload
import com.vvtech.aiassistant.features.assistant.AssistantStage
import com.vvtech.aiassistant.features.assistant.ClarificationStep
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.VoiceLanguage
import com.vvtech.aiassistant.features.assistant.VoiceRole
import com.vvtech.aiassistant.features.assistant.sanitizeUserFacingNetworkText
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
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
        voiceMode: Boolean,
        voiceLanguage: VoiceLanguage
    ): AgentStreamInteractiveResponsePlan? {
        return when (response.type) {
            TYPE_ASK_USER -> askUser(state, response, voiceMode, voiceLanguage)
            TYPE_SHOW_OPTIONS -> showOptions(state, response, voiceMode, voiceLanguage)
            TYPE_REQUEST_PERMISSION -> requestPermission(state, response, voiceMode, voiceLanguage)
            TYPE_IMPORT_DOCUMENT_REQUEST -> importDocumentRequest(state, response, voiceMode, voiceLanguage)
            else -> null
        }
    }

    fun optionsVoiceSummary(options: OptionsPayload?): String {
        val items = options?.items.orEmpty()
        if (items.isEmpty()) return ""
        val chineseUnit = if (items.any { it.looksLikePlaceCandidate() }) "家" else "个"
        val chineseSummary = items.mapIndexed { index, item ->
            "第${voiceOrdinal(index + 1)}$chineseUnit，${item.voiceOptionLabel()}"
        }.joinToString("。")
        val englishSummary = items.mapIndexed { index, item ->
            "Option ${index + 1}, ${item.voiceOptionLabel()}"
        }.joinToString(". ")
        return currentAppText(chineseSummary, englishSummary)
    }

    private fun askUser(
        state: Index9AssistantUiState,
        response: AgentChatResponse,
        voiceMode: Boolean,
        voiceLanguage: VoiceLanguage
    ): AgentStreamInteractiveResponsePlan {
        val questionItems = response.questions?.items.orEmpty().map { item ->
            item.copy(
                prompt = assistantOutputText(item.prompt, voiceLanguage),
                hint = item.hint?.let { assistantOutputText(it, voiceLanguage) },
                choices = item.choices?.map { assistantOutputText(it, voiceLanguage) }
            )
        }
        val questions = questionItems.joinToString(currentAppText("，", ", ")) { it.prompt }
        val title = response.questions
            ?.title
            ?.takeIf { it.isNotBlank() }
            ?.let { assistantOutputText(it, voiceLanguage) }
            ?: currentAppText("再确认几件事", "Confirm a Few Details")
        val localizedQuestions = response.questions?.copy(
            title = title,
            items = questionItems
        ) ?: AskQuestionsPayload(
            title = title,
            items = questionItems
        )
        if (voiceMode) {
            val voicePrompt = if (questionItems.size == 1) {
                questionItems.first().prompt.trim().ifBlank { title }
            } else {
                "$title${currentAppText("：", ": ")}$questions"
            }
            val assistantStepText =
                "$title\n${questionItems.joinToString("\n") { "· ${it.prompt}" }}"
            return AgentStreamInteractiveResponsePlan(
                nextState = state.copy(
                    stage = AssistantStage.Clarifying,
                    processingTurn = false,
                    loading = false,
                    error = null,
                    status = currentAppText("请语音回答", "Please answer by voice"),
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
                status = title.takeIf { it.isNotBlank() } ?: currentAppText("AI在确认细节", "AI is confirming details"),
                agentQuestions = localizedQuestions,
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
        voiceMode: Boolean,
        voiceLanguage: VoiceLanguage
    ): AgentStreamInteractiveResponsePlan {
        val title = response.options
            ?.title
            ?.let(ShowOptionsDisplayTextFormatter::localizedShowOptionsTitle)
            ?.let { assistantOutputText(it, voiceLanguage) }
            ?: currentAppText("请选择", "Please Select")
        val localizedOptions = response.options?.copy(
            title = title,
            items = response.options.items.map { item ->
                item.copy(
                    label = assistantOutputText(item.label, voiceLanguage),
                    detail = item.detail?.let { assistantOutputText(it, voiceLanguage) },
                    phone = item.phone?.let { assistantOutputText(it, voiceLanguage) },
                    tags = item.tags?.map { assistantOutputText(it, voiceLanguage) },
                    address = item.address?.let { assistantOutputText(it, voiceLanguage) }
                )
            }
        )
        if (voiceMode) {
            val optionsText = localizedOptions
                ?.let(ShowOptionsDisplayTextFormatter::format)
                ?: title
            return AgentStreamInteractiveResponsePlan(
                nextState = state.copy(
                    stage = AssistantStage.Clarifying,
                    processingTurn = false,
                    loading = false,
                    error = null,
                    status = title,
                    agentOptions = localizedOptions,
                    agentQuestions = null,
                    agentPermissionRequest = null,
                    agentDocumentRequest = null,
                    agentDocumentImporting = false,
                    agentPendingToolCallId = response.pendingToolCallId
                ).withVoiceInteractiveAssistantStep(optionsText),
                voicePrompt = listOf(title, optionsVoiceSummary(localizedOptions))
                    .filter(String::isNotBlank)
                    .joinToString(currentAppText("。", ". ")),
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
                agentOptions = localizedOptions,
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
        voiceMode: Boolean,
        voiceLanguage: VoiceLanguage
    ): AgentStreamInteractiveResponsePlan {
        val request = response.permissionRequest?.let { rawRequest ->
            rawRequest.copy(
                reason = rawRequest.reason?.let { assistantOutputText(it, voiceLanguage) },
                statusBeforeRequest = rawRequest.statusBeforeRequest?.let {
                    assistantOutputText(it, voiceLanguage)
                }
            )
        }
        val reason = request?.reason?.takeIf { it.isNotBlank() }
            ?: currentAppText("需要你授权后才能继续", "Permission is required to continue")
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
        voiceMode: Boolean,
        voiceLanguage: VoiceLanguage
    ): AgentStreamInteractiveResponsePlan {
        val request = response.documentImportRequest?.let { rawRequest ->
            rawRequest.copy(
                title = rawRequest.title?.let { assistantOutputText(it, voiceLanguage) },
                reason = rawRequest.reason?.let { assistantOutputText(it, voiceLanguage) }
            )
        }
        val reason = request?.reason?.takeIf { it.isNotBlank() }
            ?: currentAppText("请上传 Markdown 或 TXT 文档", "Upload a Markdown or TXT document")
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

    private fun assistantOutputText(text: String, voiceLanguage: VoiceLanguage): String =
        sanitizeUserFacingNetworkText(text, voiceLanguage)
}
