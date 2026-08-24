package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.DocumentParseResult
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText

internal class AgentStreamNormalActionEntryHandler(
    private val sessionIdProvider: () -> String?,
    private val stateProvider: () -> Index9AssistantUiState,
    private val updateUiState: ((Index9AssistantUiState) -> Index9AssistantUiState) -> Unit,
    private val submitHandler: AgentStreamNormalActionSubmitHandler
) {
    fun onOptionSelect(optionId: String) {
        val sessionId = sessionIdProvider() ?: return
        val actionDraft = AgentStreamUserActionPolicy.optionSelection(
            options = stateProvider().agentOptions,
            optionId = optionId
        )
        submitHandler.submit(
            AgentStreamNormalActionSubmitInput(
                sessionId = sessionId,
                actionDraft = actionDraft,
                stateReducer = { AgentStreamActionSubmitStatePolicy.optionSelected(it, ProcessingStatusText) },
                contextReason = "agent_select_option",
                logAction = "select_option",
                failureMessage = currentAppText("选择失败", "Selection failed")
            )
        )
    }

    fun onAnswerSubmit(answers: Map<String, Any>) {
        val sessionId = sessionIdProvider() ?: return
        val actionDraft = AgentStreamUserActionPolicy.answerSubmit(
            questions = stateProvider().agentQuestions,
            answers = answers
        )
        submitHandler.submit(
            AgentStreamNormalActionSubmitInput(
                sessionId = sessionId,
                actionDraft = actionDraft,
                stateReducer = { AgentStreamActionSubmitStatePolicy.answersSubmitted(it, ProcessingStatusText) },
                contextReason = "agent_answer_questions",
                logAction = "answer_questions",
                failureMessage = currentAppText("提交失败", "Submission failed")
            )
        )
    }

    fun onPermissionResult(
        permissionKey: String,
        androidPermission: String?,
        status: String,
        granted: Boolean,
        message: String?
    ) {
        val sessionId = sessionIdProvider() ?: return
        val actionDraft = AgentStreamUserActionPolicy.permissionResult(
            permissionKey = permissionKey,
            androidPermission = androidPermission,
            status = status,
            granted = granted,
            message = message
        )
        submitHandler.submit(
            AgentStreamNormalActionSubmitInput(
                sessionId = sessionId,
                actionDraft = actionDraft,
                appendUserEcho = false,
                stateReducer = { AgentStreamActionSubmitStatePolicy.permissionResultSubmitted(it, ProcessingStatusText) },
                contextReason = "agent_permission_result",
                logAction = "permission_result",
                failureMessage = currentAppText("权限结果提交失败", "Failed to submit permission result")
            )
        )
    }

    fun onDocumentSubmit(result: DocumentParseResult) {
        val sessionId = sessionIdProvider() ?: return
        val actionDraft = AgentStreamUserActionPolicy.documentSubmit(result)
        submitHandler.submit(
            AgentStreamNormalActionSubmitInput(
                sessionId = sessionId,
                actionDraft = actionDraft,
                stateReducer = { AgentStreamActionSubmitStatePolicy.documentSubmitted(it, ProcessingStatusText) },
                contextReason = "agent_submit_document",
                logAction = "submit_document",
                failureMessage = currentAppText("文档结果提交失败", "Failed to submit document result"),
                beforeRecover = {
                    updateUiState { it.copy(agentDocumentImporting = false) }
                }
            )
        )
    }
}

private val ProcessingStatusText: String
    get() = currentAppText("AI处理中", "AI is processing")
