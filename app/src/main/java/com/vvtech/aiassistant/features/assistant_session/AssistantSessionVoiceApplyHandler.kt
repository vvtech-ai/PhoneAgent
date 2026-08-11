package com.vvtech.aiassistant.features.assistant_session

import com.vvtech.aiassistant.core.model.AssistantActionChip
import com.vvtech.aiassistant.core.model.AssistantSessionResponse
import com.vvtech.aiassistant.features.assistant.CallPageData
import com.vvtech.aiassistant.features.assistant.ClarificationStep
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.SelectionSheetData
import com.vvtech.aiassistant.features.assistant.VoiceLanguage
import com.vvtech.aiassistant.features.assistant.viewmodel.DefaultConfirmLabel
import com.vvtech.aiassistant.features.assistant.viewmodel.DefaultIdleStatus
import com.vvtech.aiassistant.features.assistant.viewmodel.InteractionChannel
import com.vvtech.aiassistant.features.assistant.viewmodel.previewText
import com.vvtech.aiassistant.features.assistant.viewmodel.supportsSelectionDrivenDetailSupplement
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.update

internal data class AssistantSessionVoiceApplyHandlerDeps(
    val uiState: MutableStateFlow<Index9AssistantUiState>,
    val state: AssistantSessionVoiceApplyStateAccess,
    val actions: AssistantSessionVoiceApplyActions,
    val statusText: AssistantSessionVoiceApplyStatusText
)

internal data class AssistantSessionVoiceApplyStateAccess(
    val setVoiceTaskId: (String) -> Unit,
    val pendingSelectionContinuation: () -> AssistantSessionPendingSelectionContinuation?,
    val setPendingSelectionContinuation: (AssistantSessionPendingSelectionContinuation?) -> Unit,
    val setPendingAiCallLaunch: (Boolean) -> Unit,
    val setPendingFreshTask: (Boolean) -> Unit,
    val clearActiveDialogContext: () -> Unit,
    val setPrimarySummaryAction: (AssistantActionChip?) -> Unit,
    val latestCallPageSeed: () -> CallPageData,
    val setLatestCallPageSeed: (CallPageData) -> Unit,
    val activeInteractionChannel: () -> InteractionChannel,
    val lastCommittedUserTranscript: () -> String?
)

internal data class AssistantSessionVoiceApplyActions(
    val clearConsumedSelectionSheetIfTaskChanged: (String) -> Unit,
    val snapshotVisibleClarificationSteps: (Index9AssistantUiState) -> List<ClarificationStep>,
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
    val startDetailSupplementFromSelection: (AssistantSessionResponse, String) -> Unit,
    val stopVoiceInteraction: () -> Unit,
    val log: (String) -> Unit,
    val handleAfterVoiceApply: (AssistantSessionVoicePostApplyContext) -> Unit
)

internal data class AssistantSessionVoiceApplyStatusText(
    val currentLanguage: () -> VoiceLanguage,
    val taskReadyStatus: () -> String,
    val continuingStatus: () -> String,
    val selectionStatus: (SelectionSheetData) -> String
)

internal class AssistantSessionVoiceApplyHandler(
    private val deps: AssistantSessionVoiceApplyHandlerDeps
) {
    fun apply(session: AssistantSessionResponse) {
        deps.state.setVoiceTaskId(session.session.taskId)
        deps.actions.clearConsumedSelectionSheetIfTaskChanged(session.session.taskId)
        val previousSelectionSheet = deps.uiState.value.selectionSheet
        val selectionContinuation = deps.state.pendingSelectionContinuation()
            ?: inferSelectionContinuationFromPreviousSheet(session.session.sceneType, previousSelectionSheet)
        deps.state.setPendingSelectionContinuation(null)
        if (deps.uiState.value.showAiCallPage) {
            deps.state.setPendingAiCallLaunch(false)
        }
        deps.state.setPendingFreshTask(false)
        deps.state.clearActiveDialogContext()

        val currentSteps = deps.actions.snapshotVisibleClarificationSteps(deps.uiState.value)
        val backendSteps = AssistantSessionDialogueStepPolicy.mapClarificationSteps(
            session.messages,
            hideInternalSync = deps.statusText.currentLanguage() != VoiceLanguage.Chinese
        )
        val mappedSteps = backendSteps.ifEmpty { currentSteps }
        val newestBackendAssistantPrompt = AssistantSessionDialogueStepPolicy.resolveLatestBackendAssistantPrompt(
            currentSteps,
            backendSteps
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
            if (actionable != null || selectionSheet != null) {
                deps.actions.stopVoiceInteraction()
            }
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
            deps.actions.stopVoiceInteraction()
            deps.actions.startDetailSupplementFromSelection(session, selectionContinuation!!.targetName)
            return
        }
        deps.state.setPrimarySummaryAction(actionable?.primaryAction)
        deps.state.setLatestCallPageSeed(actionable?.callPageSeed ?: deps.state.latestCallPageSeed())
        val suppressRealtimeContinuation = selectionContinuation != null
        val keepRealtimeDialog = false
        val preserveRealtimeUi = false
        val shouldDeferLatestAssistantPromptForVoice = false
        val shouldPlayLatestAssistantPromptAfterVoiceStop =
            deps.state.activeInteractionChannel() == InteractionChannel.VOICE &&
                !newestBackendAssistantPrompt.isNullOrBlank() &&
                (actionable != null || selectionSheet != null) &&
                !shouldDeferLatestAssistantPromptForVoice
        val displayedSteps = if (shouldDeferLatestAssistantPromptForVoice) {
            AssistantSessionDialogueStepPolicy.removeTrailingAssistantPrompt(
                mappedSteps,
                newestBackendAssistantPrompt
            )
        } else {
            mappedSteps
        }
        deps.actions.log(
            "applySession taskId=${session.session.taskId} scene=${session.session.sceneType} " +
                "keepRealtimeDialog=$keepRealtimeDialog preserveRealtimeUi=$preserveRealtimeUi " +
                "backendSteps=${backendSteps.size} currentSteps=${currentSteps.size} " +
                "selection=${selectionSheet != null} actionable=${actionable != null} " +
                "newBackendPrompt=${previewText(newestBackendAssistantPrompt)} " +
                "deferPrompt=$shouldDeferLatestAssistantPromptForVoice displayedSteps=${displayedSteps.size}"
        )
        if (actionable != null || selectionSheet != null) {
            deps.actions.stopVoiceInteraction()
        }
        deps.uiState.update { current ->
            AssistantSessionApplyStateReducer.reduceVoiceApplyState(
                current,
                AssistantSessionApplyStateReducer.VoiceContext(
                    identity = AssistantSessionApplyStateReducer.SessionIdentity(
                        taskId = session.session.taskId,
                        sceneType = session.session.sceneType,
                        taskStatus = session.session.taskStatus
                    ),
                    content = AssistantSessionApplyStateReducer.ApplyContent(
                        steps = displayedSteps,
                        selectionSheet = selectionSheet,
                        summary = actionable?.summary,
                        confirmLabel = actionable?.confirmLabel ?: DefaultConfirmLabel
                    ),
                    statusText = AssistantSessionApplyStateReducer.ApplyStatusText(
                        taskReadyStatus = deps.statusText.taskReadyStatus(),
                        selectionStatus = selectionSheet?.let { deps.statusText.selectionStatus(it) },
                        continuingStatus = deps.statusText.continuingStatus(),
                        idleStatus = DefaultIdleStatus
                    ),
                    realtime = AssistantSessionApplyStateReducer.VoiceRealtimeOptions(
                        preserveRealtimeUi = preserveRealtimeUi,
                        keepRealtimeDialog = keepRealtimeDialog,
                        shouldDeferLatestAssistantPromptForVoice = shouldDeferLatestAssistantPromptForVoice,
                        newestBackendAssistantPrompt = newestBackendAssistantPrompt
                    )
                )
            )
        }

        deps.actions.handleAfterVoiceApply(
            AssistantSessionVoicePostApplyContext(
                session = session,
                actionablePresent = actionable != null,
                selectionSheetPresent = selectionSheet != null,
                mappedStepsPresent = mappedSteps.isNotEmpty(),
                suppressRealtimeContinuation = suppressRealtimeContinuation,
                keepRealtimeDialog = keepRealtimeDialog,
                shouldPlayLatestAssistantPromptAfterVoiceStop = shouldPlayLatestAssistantPromptAfterVoiceStop,
                newestBackendAssistantPrompt = newestBackendAssistantPrompt
            )
        )
    }

    private fun inferSelectionContinuationFromPreviousSheet(
        sceneType: String,
        previousSelectionSheet: SelectionSheetData?
    ): AssistantSessionPendingSelectionContinuation? {
        if (!supportsSelectionDrivenDetailSupplement(sceneType)) return null
        val sheet = previousSelectionSheet ?: return null
        val utterance = deps.state.lastCommittedUserTranscript().orEmpty()
        val option = AssistantSessionSelectionSheetPolicy.resolveVoiceSelectionOption(utterance, sheet) ?: return null
        deps.actions.log(
            "applySession inferred selection continuation scene=$sceneType " +
                "target=${option.title} utterance=${previewText(utterance)}"
        )
        return AssistantSessionPendingSelectionContinuation(
            sceneType = sceneType,
            targetName = option.title
        )
    }
}
