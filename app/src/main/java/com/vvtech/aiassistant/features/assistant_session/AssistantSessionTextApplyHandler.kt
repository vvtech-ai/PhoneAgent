package com.vvtech.aiassistant.features.assistant_session

import com.vvtech.aiassistant.core.model.AssistantActionChip
import com.vvtech.aiassistant.core.model.AssistantSessionResponse
import com.vvtech.aiassistant.features.assistant.CallPageData
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.SelectionSheetData
import com.vvtech.aiassistant.features.assistant.VoiceLanguage
import com.vvtech.aiassistant.features.assistant.viewmodel.DefaultConfirmLabel
import com.vvtech.aiassistant.features.assistant.viewmodel.DefaultIdleStatus
import com.vvtech.aiassistant.features.assistant.viewmodel.InteractionChannel
import com.vvtech.aiassistant.features.assistant.viewmodel.isTerminalTaskStatus
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.update

internal data class AssistantSessionTextApplyHandlerDeps(
    val uiState: MutableStateFlow<Index9AssistantUiState>,
    val state: AssistantSessionTextApplyStateAccess,
    val actions: AssistantSessionTextApplyActions,
    val statusText: AssistantSessionTextApplyStatusText
)

internal data class AssistantSessionTextApplyStateAccess(
    val setTextTaskId: (String?) -> Unit,
    val pendingSelectionContinuation: () -> AssistantSessionPendingSelectionContinuation?,
    val setPendingSelectionContinuation: (AssistantSessionPendingSelectionContinuation?) -> Unit,
    val pendingAiCallLaunch: () -> Boolean,
    val setPendingAiCallLaunch: (Boolean) -> Unit,
    val setActiveInteractionChannel: (InteractionChannel) -> Unit,
    val setPrimarySummaryAction: (AssistantActionChip?) -> Unit,
    val latestCallPageSeed: () -> CallPageData,
    val setLatestCallPageSeed: (CallPageData) -> Unit
)

internal data class AssistantSessionTextApplyActions(
    val clearConsumedSelectionSheetIfTaskChanged: (String) -> Unit,
    val shouldPreserveTerminalResult: (AssistantSessionResponse) -> Boolean,
    val preserveTerminalResult: (AssistantSessionResponse) -> Unit,
    val resetToIdleHome: () -> Unit,
    val refreshHistory: () -> Unit,
    val resolveActionableSummary: (AssistantSessionResponse) -> AssistantSessionActionableSummary?,
    val resolveSelectionSheet: (AssistantSessionResponse) -> SelectionSheetData?,
    val shouldEnterDetailSupplement: (String, String, AssistantSessionActionableSummary?) -> Boolean,
    val startDetailSupplement: (AssistantSessionResponse, AssistantSessionActionableSummary) -> Unit,
    val shouldForceSelectionDetailSupplement: (
        AssistantSessionResponse,
        AssistantSessionActionableSummary?,
        SelectionSheetData?,
        AssistantSessionPendingSelectionContinuation?
    ) -> Boolean,
    val startDetailSupplementFromSelection: (AssistantSessionResponse, String) -> Unit
)

internal data class AssistantSessionTextApplyStatusText(
    val currentLanguage: () -> VoiceLanguage,
    val taskReadyStatus: () -> String,
    val continuingStatus: () -> String,
    val selectionStatus: (SelectionSheetData) -> String
)

internal class AssistantSessionTextApplyHandler(
    private val deps: AssistantSessionTextApplyHandlerDeps
) {
    fun apply(session: AssistantSessionResponse) {
        deps.state.setTextTaskId(session.session.taskId)
        deps.actions.clearConsumedSelectionSheetIfTaskChanged(session.session.taskId)
        val selectionContinuation = deps.state.pendingSelectionContinuation()
        deps.state.setPendingSelectionContinuation(null)
        if (isTerminalTaskStatus(session.session.taskStatus)) {
            applyTerminalTextSession(session)
            return
        }

        val backendSteps = AssistantSessionDialogueStepPolicy.mapClarificationSteps(
            session.messages,
            hideInternalSync = deps.statusText.currentLanguage() != VoiceLanguage.Chinese
        )
        val actionable = deps.actions.resolveActionableSummary(session)
        val selectionSheet = deps.actions.resolveSelectionSheet(session)
        if (
            deps.actions.shouldEnterDetailSupplement(
                session.session.sceneType,
                session.session.taskId,
                actionable
            )
        ) {
            deps.actions.startDetailSupplement(session, actionable!!)
            return
        }
        if (
            deps.actions.shouldForceSelectionDetailSupplement(
                session,
                actionable,
                selectionSheet,
                selectionContinuation
            )
        ) {
            deps.actions.startDetailSupplementFromSelection(session, selectionContinuation!!.targetName)
            return
        }
        deps.state.setPrimarySummaryAction(actionable?.primaryAction)
        deps.state.setLatestCallPageSeed(actionable?.callPageSeed ?: deps.state.latestCallPageSeed())

        deps.uiState.update { current ->
            AssistantSessionApplyStateReducer.reduceTextApplyState(
                current,
                AssistantSessionApplyStateReducer.TextContext(
                    identity = AssistantSessionApplyStateReducer.SessionIdentity(
                        taskId = session.session.taskId,
                        sceneType = session.session.sceneType,
                        taskStatus = session.session.taskStatus
                    ),
                    content = AssistantSessionApplyStateReducer.ApplyContent(
                        steps = backendSteps,
                        selectionSheet = selectionSheet,
                        summary = actionable?.summary,
                        confirmLabel = actionable?.confirmLabel ?: DefaultConfirmLabel
                    ),
                    statusText = AssistantSessionApplyStateReducer.ApplyStatusText(
                        taskReadyStatus = deps.statusText.taskReadyStatus(),
                        selectionStatus = selectionSheet?.let { deps.statusText.selectionStatus(it) },
                        continuingStatus = deps.statusText.continuingStatus(),
                        idleStatus = DefaultIdleStatus
                    )
                )
            )
        }
    }

    private fun applyTerminalTextSession(session: AssistantSessionResponse) {
        deps.state.setTextTaskId(null)
        if (deps.state.pendingAiCallLaunch() || deps.uiState.value.showAiCallPage) {
            deps.state.setPendingAiCallLaunch(false)
            deps.uiState.update {
                it.copy(
                    taskId = session.session.taskId,
                    sceneType = session.session.sceneType,
                    taskStatus = session.session.taskStatus,
                    processingTurn = false,
                    loading = false,
                    error = null
                )
            }
            return
        }
        deps.state.setActiveInteractionChannel(InteractionChannel.NONE)
        if (deps.actions.shouldPreserveTerminalResult(session)) {
            deps.actions.preserveTerminalResult(session)
            deps.actions.refreshHistory()
            return
        }
        deps.actions.resetToIdleHome()
        deps.actions.refreshHistory()
    }
}
