package com.vvtech.aiassistant.features.assistant_session

import com.vvtech.aiassistant.core.model.AssistantSessionResponse
import com.vvtech.aiassistant.features.assistant.ClarificationStep
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.SelectionSheetData
import com.vvtech.aiassistant.features.assistant.SummaryData
import com.vvtech.aiassistant.features.assistant.VoiceLanguage
import com.vvtech.aiassistant.features.assistant.VoiceRole
import com.vvtech.aiassistant.features.assistant.viewmodel.DefaultConfirmLabel

/**
 * 会话状态映射 + selection sheet / detail supplement 的入口。
 * 不持有完整 ViewModel；依赖通过 [SessionMapperDeps] 显式注入。
 */
internal class SessionMapper(
    private val deps: SessionMapperDeps
) {
    private val initialApplyHandler = AssistantSessionInitialApplyHandler(
        AssistantSessionInitialApplyHandlerDeps(
            stateHolder = AssistantSessionInitialApplyStateHolder(deps.uiState),
            state = AssistantSessionInitialApplyStateAccess(
                pendingAiCallLaunch = deps.taskState.pendingAiCallLaunch,
                setPendingAiCallLaunch = deps.taskState.setPendingAiCallLaunch,
                setPendingFreshTask = deps.taskState.setPendingFreshTask
            ),
            actions = AssistantSessionInitialApplyActions(
                applyNonTerminalSession = ::applySession,
                resetToIdleHome = ::resetToIdleHome,
                refreshHistory = deps.actions.refreshHistory
            )
        )
    )
    private val textApplyHandler = AssistantSessionTextApplyHandler(
        AssistantSessionTextApplyHandlerDeps(
            uiState = deps.uiState,
            state = AssistantSessionTextApplyStateAccess(
                setTextTaskId = deps.taskState.setTextTaskId,
                pendingSelectionContinuation = deps.conversationState.pendingSelectionContinuation,
                setPendingSelectionContinuation = deps.conversationState.setPendingSelectionContinuation,
                pendingAiCallLaunch = deps.taskState.pendingAiCallLaunch,
                setPendingAiCallLaunch = deps.taskState.setPendingAiCallLaunch,
                setActiveInteractionChannel = deps.taskState.setActiveInteractionChannel,
                setPrimarySummaryAction = deps.conversationState.setPrimarySummaryAction,
                latestCallPageSeed = deps.conversationState.latestCallPageSeed,
                setLatestCallPageSeed = deps.conversationState.setLatestCallPageSeed
            ),
            actions = AssistantSessionTextApplyActions(
                clearConsumedSelectionSheetIfTaskChanged = ::clearConsumedSelectionSheetIfTaskChanged,
                shouldPreserveTerminalResult = initialApplyHandler::shouldPreserveTerminalResult,
                preserveTerminalResult = initialApplyHandler::preserveTerminalResult,
                resetToIdleHome = ::resetToIdleHome,
                refreshHistory = deps.actions.refreshHistory,
                resolveActionableSummary = ::resolveActionableSummary,
                resolveSelectionSheet = ::resolveSelectionSheet,
                shouldEnterDetailSupplement = ::shouldEnterDetailSupplement,
                startDetailSupplement = ::startDetailSupplement,
                shouldForceSelectionDetailSupplement = ::shouldForceSelectionDetailSupplement,
                startDetailSupplementFromSelection = ::startDetailSupplementFromSelection
            ),
            statusText = AssistantSessionTextApplyStatusText(
                currentLanguage = ::currentLanguage,
                taskReadyStatus = ::taskReadyStatus,
                continuingStatus = ::continuingStatus,
                selectionStatus = ::selectionStatus
            )
        )
    )
    private val voiceApplyHandler = AssistantSessionVoiceApplyHandler(
        AssistantSessionVoiceApplyHandlerDeps(
            uiState = deps.uiState,
            state = AssistantSessionVoiceApplyStateAccess(
                setVoiceTaskId = deps.taskState.setVoiceTaskId,
                pendingSelectionContinuation = deps.conversationState.pendingSelectionContinuation,
                setPendingSelectionContinuation = deps.conversationState.setPendingSelectionContinuation,
                setPendingAiCallLaunch = deps.taskState.setPendingAiCallLaunch,
                setPendingFreshTask = deps.taskState.setPendingFreshTask,
                clearActiveDialogContext = deps.conversationState.clearActiveDialogContext,
                setPrimarySummaryAction = deps.conversationState.setPrimarySummaryAction,
                latestCallPageSeed = deps.conversationState.latestCallPageSeed,
                setLatestCallPageSeed = deps.conversationState.setLatestCallPageSeed,
                activeInteractionChannel = deps.taskState.activeInteractionChannel,
                lastCommittedUserTranscript = deps.conversationState.lastCommittedUserTranscript
            ),
            actions = AssistantSessionVoiceApplyActions(
                clearConsumedSelectionSheetIfTaskChanged = ::clearConsumedSelectionSheetIfTaskChanged,
                snapshotVisibleClarificationSteps = ::snapshotVisibleClarificationSteps,
                resolveActionableSummary = ::resolveActionableSummary,
                resolveSelectionSheet = ::resolveSelectionSheet,
                shouldEnterDetailSupplement = ::shouldEnterDetailSupplement,
                startDetailSupplement = ::startDetailSupplement,
                shouldForceSelectionDetailSupplement = ::shouldForceSelectionDetailSupplement,
                startDetailSupplementFromSelection = ::startDetailSupplementFromSelection,
                stopVoiceInteraction = { deps.actions.stopVoiceInteraction("session_voice_apply") },
                log = deps.actions.log,
                handleAfterVoiceApply = deps.handlers.voicePostApplyHandler::handleAfterVoiceApply
            ),
            statusText = AssistantSessionVoiceApplyStatusText(
                currentLanguage = ::currentLanguage,
                taskReadyStatus = ::taskReadyStatus,
                continuingStatus = ::continuingStatus,
                selectionStatus = ::selectionStatus
            )
        )
    )

    private fun currentLanguage(): VoiceLanguage = deps.statusText.currentLanguage()

    private fun taskReadyStatus(): String = deps.statusText.taskReadyStatus()

    private fun continuingStatus(): String = when (currentLanguage()) {
        VoiceLanguage.English -> "I am continuing with this request."
        VoiceLanguage.Japanese -> "この依頼を続けて処理しています。"
        VoiceLanguage.Chinese -> "我还在顺着这件事继续往下处理"
    }

    private fun selectionStatus(sheet: SelectionSheetData): String = when (currentLanguage()) {
        VoiceLanguage.English -> "Please choose one ${sheet.targetLabel} from the list."
        VoiceLanguage.Japanese -> "リストから${sheet.targetLabel}を1つ選んでください。"
        VoiceLanguage.Chinese -> "请先从底部列表里选一个${sheet.targetLabel}"
    }

    fun appendClarificationStep(
        role: VoiceRole,
        text: String,
        isUserActionEcho: Boolean = false,
    ) {
        deps.handlers.clarificationStepHandler.appendClarificationStep(
            role = role,
            text = text,
            isUserActionEcho = isUserActionEcho,
        )
    }

    fun snapshotVisibleClarificationSteps(state: Index9AssistantUiState): List<ClarificationStep> {
        return deps.handlers.clarificationStepHandler.snapshotVisibleClarificationSteps(state)
    }

    fun commitVisibleAssistantTranscriptIfNeeded() {
        deps.handlers.clarificationStepHandler.commitVisibleAssistantTranscriptIfNeeded()
    }

    fun applyInitialSession(session: AssistantSessionResponse) {
        initialApplyHandler.apply(session)
    }

    fun applyTextSession(session: AssistantSessionResponse) {
        textApplyHandler.apply(session)
    }

    fun applySession(session: AssistantSessionResponse) {
        voiceApplyHandler.apply(session)
    }

    fun scheduleAutoResumeListening(delayMillis: Long) =
        deps.handlers.voicePostApplyHandler.scheduleAutoResumeListening(delayMillis)

    fun estimateAssistantResumeDelay(session: AssistantSessionResponse): Long =
        deps.handlers.voicePostApplyHandler.estimateAssistantResumeDelay(session)

    fun resetToIdleHome() {
        deps.handlers.idleResetHandler.resetToIdleHome()
    }

    fun resolveActionableSummary(session: AssistantSessionResponse): AssistantSessionActionableSummary? {
        return AssistantSessionActionableSummaryPolicy.resolve(
            session = session,
            context = AssistantSessionActionableSummaryPolicy.BuildContext(
                language = currentLanguage(),
                contactTaskId = deps.detailState.contactTaskId(),
                contactValue = deps.detailState.contactValue(),
                detailTaskId = deps.detailState.detailTaskId(),
                detailValue = deps.detailState.detailValue(),
                contactLabel = deps.statusText.contactLabel(),
                detailLabel = deps.statusText.detailLabel(),
                defaultConfirmLabel = DefaultConfirmLabel
            )
        )
    }

    fun shouldEnterDetailSupplement(
        sceneType: String,
        taskId: String,
        actionable: AssistantSessionActionableSummary?
    ): Boolean = AssistantSessionDetailSupplementPolicy.shouldEnterDetailSupplement(
        sceneType,
        taskId,
        actionable != null,
        deps.detailState.completedTaskId()
    )

    fun shouldForceSelectionDetailSupplement(
        session: AssistantSessionResponse,
        actionable: AssistantSessionActionableSummary?,
        selectionSheet: SelectionSheetData?,
        selectionContinuation: AssistantSessionPendingSelectionContinuation?
    ): Boolean = AssistantSessionDetailSupplementPolicy.shouldForceSelectionDetailSupplement(
        session.session.sceneType,
        actionable != null,
        selectionSheet != null,
        selectionContinuation?.sceneType
    )

    fun startDetailSupplement(
        session: AssistantSessionResponse,
        actionable: AssistantSessionActionableSummary
    ) {
        deps.handlers.detailSupplementHandler.startFromActionable(session, actionable)
    }

    fun startDetailSupplementFromSelection(
        session: AssistantSessionResponse,
        targetName: String
    ) {
        deps.handlers.detailSupplementHandler.startFromSelection(session, targetName)
    }

    fun decorateSummaryWithSupplement(taskId: String, summary: SummaryData): SummaryData {
        return AssistantSessionDetailSupplementPolicy.decorateSummaryWithSupplement(
            taskId = taskId,
            summary = summary,
            contactTaskId = deps.detailState.contactTaskId(),
            contactValue = deps.detailState.contactValue(),
            detailTaskId = deps.detailState.detailTaskId(),
            detailValue = deps.detailState.detailValue(),
            contactLabel = deps.statusText.contactLabel(),
            detailLabel = deps.statusText.detailLabel()
        )
    }

    fun resolveSelectionSheet(session: AssistantSessionResponse): SelectionSheetData? {
        val sheet = AssistantSessionSelectionSheetPolicy.resolveSelectionSheetFromSession(session, currentLanguage())
        if (sheet != null && shouldSuppressSelectionSheet(session.session.taskId, sheet)) {
            deps.actions.log(
                "resolveSelectionSheet suppressed duplicated sheet taskId=${session.session.taskId} " +
                    "signature=${AssistantSessionSelectionSheetPolicy.signature(sheet)}"
            )
            return null
        }
        return sheet
    }

    fun shouldSuppressSelectionSheet(taskId: String, sheet: SelectionSheetData): Boolean {
        return AssistantSessionSelectionSheetPolicy.shouldSuppressSelectionSheet(
            taskId = taskId,
            sheet = sheet,
            consumedTaskId = deps.selectionState.consumedTaskId(),
            consumedSignature = deps.selectionState.consumedSignature()
        )
    }

    fun clearConsumedSelectionSheetIfTaskChanged(taskId: String) {
        if (
            AssistantSessionSelectionSheetPolicy.shouldClearConsumedSelectionSheet(
                taskId = taskId,
                consumedTaskId = deps.selectionState.consumedTaskId()
            )
        ) {
            clearConsumedSelectionSheetSuppression()
        }
    }

    fun clearConsumedSelectionSheetSuppression() {
        deps.selectionState.setConsumedTaskId(null)
        deps.selectionState.setConsumedSignature(null)
    }
}
