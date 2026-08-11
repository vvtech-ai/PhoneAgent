package com.vvtech.aiassistant.features.assistant_session

import com.vvtech.aiassistant.features.assistant.*

import androidx.lifecycle.viewModelScope
import com.vvtech.aiassistant.core.model.AssistantSessionResponse
import com.vvtech.aiassistant.core.model.DetailSupplementPromptResponse
import com.vvtech.aiassistant.features.assistant.AssistantStage
import com.vvtech.aiassistant.features.assistant.AssistantViewModel
import com.vvtech.aiassistant.features.assistant.DetailSupplementPageData
import com.vvtech.aiassistant.features.assistant.DetailSupplementQuestionData
import com.vvtech.aiassistant.features.assistant.VoiceLanguage
import com.vvtech.aiassistant.features.assistant.localizedDetailLabel
import com.vvtech.aiassistant.features.assistant.viewmodel.DefaultConfirmLabel
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

internal class AssistantSessionDetailSupplementHandler(
    private val viewModel: AssistantViewModel,
    private val detailPromptUseCase: AssistantSessionDetailPromptUseCase
) {
    fun startFromActionable(
        session: AssistantSessionResponse,
        actionable: AssistantSessionActionableSummary
    ) {
        start(
            session = session,
            targetName = actionable.summary.target,
            confirmLabel = actionable.confirmLabel,
            beforeState = {
                viewModel.pendingDetailActionable = actionable
                viewModel.primarySummaryAction = actionable.primaryAction
                viewModel.latestCallPageSeed = actionable.callPageSeed
            }
        )
    }

    fun startFromSelection(
        session: AssistantSessionResponse,
        targetName: String
    ) {
        start(
            session = session,
            targetName = targetName,
            confirmLabel = DefaultConfirmLabel,
            beforeState = {
                viewModel.pendingDetailActionable = null
                viewModel.primarySummaryAction = null
            }
        )
    }

    private fun start(
        session: AssistantSessionResponse,
        targetName: String,
        confirmLabel: String,
        beforeState: () -> Unit
    ) {
        val taskId = session.session.taskId
        resetSupplementStateIfNeeded(taskId)
        beforeState()
        viewModel.internalUiState.update {
            it.copy(
                taskId = taskId,
                sceneType = session.session.sceneType,
                taskStatus = session.session.taskStatus,
                stage = AssistantStage.Recognized,
                status = detailGateStatus(),
                clarificationSteps = emptyList(),
                liveUserTranscript = null,
                liveAssistantTranscript = null,
                selectionSheet = null,
                summary = null,
                detailSupplement = DetailSupplementPageData(
                    taskId = taskId,
                    sceneType = session.session.sceneType,
                    title = detailTitle(),
                    intro = detailIntro(session.session.sceneType),
                    targetName = targetName,
                    loading = true
                ),
                confirmLabel = confirmLabel,
                processingTurn = false,
                listening = false,
                loading = false,
                error = null
            )
        }
        loadPrompts(taskId, session.session.sceneType)
    }

    private fun resetSupplementStateIfNeeded(taskId: String) {
        if (viewModel.detailSupplementCompletedTaskId == taskId) return
        viewModel.detailSupplementContactTaskId = null
        viewModel.detailSupplementContactValue = null
        viewModel.detailSupplementInfoTaskId = null
        viewModel.detailSupplementInfoValue = null
    }

    private fun loadPrompts(taskId: String, sceneType: String) {
        viewModel.viewModelScope.launch {
            val promptResponse = detailPromptUseCase.loadPrompts(
                sceneType = sceneType,
                fallbackTitle = detailTitle(),
                fallbackIntro = detailIntro(sceneType)
            )
            val localizedPrompt = localizedPromptResponse(sceneType, promptResponse)
            viewModel.internalUiState.update { state ->
                if (state.detailSupplement?.taskId != taskId) {
                    state
                } else {
                    state.copy(
                        detailSupplement = state.detailSupplement.copy(
                            title = localizedPrompt.title,
                            intro = localizedPrompt.intro,
                            questions = localizedPrompt.questions.map { question ->
                                DetailSupplementQuestionData(
                                    questionId = question.questionId,
                                    prompt = question.prompt,
                                    answerType = question.answerType,
                                    dependsOnQuestionId = question.dependsOnQuestionId,
                                    dependsOnAnswer = question.dependsOnAnswer
                                )
                            },
                            loading = false
                        )
                    )
                }
            }
        }
    }

    private fun detailTitle(): String = viewModel.localizedDetailLabel()

    private fun detailGateStatus(): String = when (viewModel.currentVoiceLanguage()) {
        VoiceLanguage.English -> "Confirm the booking contact first, then add any extra preferences."
        VoiceLanguage.Japanese -> "先に予約者情報を確認し、その後で追加条件を指定できます。"
        VoiceLanguage.Chinese -> "先确认预订人信息，再决定是否补充细节"
    }

    private fun detailIntro(sceneType: String): String =
        AssistantSessionDetailSupplementPolicy.detailIntro(viewModel.currentVoiceLanguage(), sceneType)

    private fun localizedPromptResponse(
        sceneType: String,
        promptResponse: DetailSupplementPromptResponse
    ): DetailSupplementPromptResponse = AssistantSessionDetailSupplementPolicy.localizedPromptResponse(
        viewModel.currentVoiceLanguage(),
        sceneType,
        detailTitle(),
        promptResponse
    )
}
