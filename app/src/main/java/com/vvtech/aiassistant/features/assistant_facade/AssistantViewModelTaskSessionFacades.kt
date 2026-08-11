package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.core.model.AssistantSessionResponse
import com.vvtech.aiassistant.core.model.ContactResolutionPayload
import com.vvtech.aiassistant.core.model.StructuredAssistantUnderstanding
import com.vvtech.aiassistant.core.model.SelectedContactTaskContext
import com.vvtech.aiassistant.features.assistant_session.AssistantSessionActionableSummary
import com.vvtech.aiassistant.features.assistant_session.AssistantSessionPendingSelectionContinuation
import com.vvtech.aiassistant.features.assistant_session.AssistantSessionSelectionSheetPolicy
import com.vvtech.aiassistant.features.assistant_agent.AgentInitialSkillLaunchStore
import com.vvtech.aiassistant.model.DeviceContactPayload
import com.vvtech.aiassistant.model.OcrAttachmentContextPayload
import com.vvtech.aiassistant.model.TaskListItem
import com.vvtech.aiassistant.model.UserContextPayload

internal fun AssistantViewModel.applyNetworkTaskErrorState(raw: String? = null) =
    taskErrorRecoveryHolder.applyNetworkTaskErrorState(raw)

internal fun AssistantViewModel.markTaskErrorRecoveryInProgress(status: String = "EXECUTION_ERROR") =
    taskErrorRecoveryHolder.markTaskErrorRecoveryInProgress(status)

internal fun AssistantViewModel.markTaskErrorRecoveryConfirmed(
    reason: String,
    promoteToRunning: Boolean = true
) = taskErrorRecoveryHolder.markTaskErrorRecoveryConfirmed(reason, promoteToRunning)

internal fun AssistantViewModel.pendingExecutionErrorExitSessions(): MutableSet<String> =
    taskErrorRecoveryHolder.pendingExecutionErrorExitSessions()

internal fun AssistantViewModel.rememberPendingExecutionErrorExit(sessionId: String) =
    taskErrorRecoveryHolder.rememberPendingExecutionErrorExit(sessionId)

internal fun AssistantViewModel.pendingExecutionErrorRecoveredSessions(): MutableSet<String> =
    taskErrorRecoveryHolder.pendingExecutionErrorRecoveredSessions()

internal suspend fun AssistantViewModel.syncPendingExecutionErrorExitSessions(): Boolean =
    taskErrorRecoveryHolder.syncPendingExecutionErrorExitSessions()

internal suspend fun AssistantViewModel.syncPendingExecutionErrorRecoveredSessions(): Boolean =
    taskErrorRecoveryHolder.syncPendingExecutionErrorRecoveredSessions()

internal fun AssistantViewModel.registerTaskErrorNetworkCallback() =
    taskErrorRecoveryHolder.registerTaskErrorNetworkCallback()

internal fun AssistantViewModel.unregisterTaskErrorNetworkCallback() =
    taskErrorRecoveryHolder.unregisterTaskErrorNetworkCallback()

internal fun AssistantViewModel.markSystemDeviceContactsLoading() =
    userContextHolder.markSystemDeviceContactsLoading()

internal fun AssistantViewModel.updateSystemDeviceContactsCache(contacts: List<DevicePhoneContact>) =
    userContextHolder.updateSystemDeviceContactsCache(contacts)

internal fun AssistantViewModel.clearSystemDeviceContactsCache() =
    userContextHolder.clearSystemDeviceContactsCache()

internal fun AssistantViewModel.updatePureVoiceOcrContext(
    attachments: List<OcrAttachmentContextPayload>
) = userContextHolder.updatePureVoiceOcrContext(attachments)

internal suspend fun AssistantViewModel.loadSystemDeviceContactsForUi(): List<DevicePhoneContact> =
    userContextHolder.loadSystemDeviceContactsForUi()

internal fun AssistantViewModel.currentAgentUserContext(
    deviceContacts: List<DeviceContactPayload> = emptyList()
): UserContextPayload = userContextHolder.currentAgentUserContext(deviceContacts)

internal suspend fun AssistantViewModel.currentFreshAgentUserContext(
    reason: String,
    message: String? = null
): UserContextPayload = userContextHolder.currentFreshAgentUserContext(reason, message)

internal fun AssistantViewModel.currentPermissionStatusSnapshot(): Map<String, String> =
    userContextHolder.currentPermissionStatusSnapshot()

fun AssistantViewModel.initialize() =
    runtimeLifecycleHandler.initialize()

fun AssistantViewModel.onAccountIdentityChanged(hasSignedInAccount: Boolean) =
    runtimeLifecycleHandler.onAccountIdentityChanged(hasSignedInAccount)

fun AssistantViewModel.loadLocationIfPermitted() =
    userContextHolder.loadLocationIfPermitted()

fun AssistantViewModel.submitTextTask(rawText: String) =
    conversationSubmitActionHandler.submitTextTask(rawText)

fun AssistantViewModel.submitSingleFlowTask(
    rawText: String,
    voiceResponse: Boolean,
    selectedContact: SelectedContactTaskContext? = null
) = conversationSubmitActionHandler.submitSingleFlowTask(rawText, voiceResponse, selectedContact)

internal fun AssistantViewModel.armSelectedContactForNextTurn(
    selectedContact: SelectedContactTaskContext?
) = conversationSubmitActionHandler.armSelectedContactForNextTurn(selectedContact)

fun AssistantViewModel.submitSceneSupplementTask(rawText: String) =
    conversationSubmitActionHandler.submitSceneSupplementTask(rawText)

internal fun AssistantViewModel.submitVoiceSupplementTask(
    rawText: String,
    appendUserStep: Boolean = true
) = conversationSubmitActionHandler.submitVoiceSupplementTask(rawText, appendUserStep)

internal suspend fun AssistantViewModel.ensureTextSession(): String =
    channelSessionClient.ensureTextSession()

internal suspend fun AssistantViewModel.sendActionThroughActiveChannel(
    actionId: String,
    actionLabel: String?
): AssistantSessionResponse =
    channelSessionClient.sendActionThroughActiveChannel(actionId, actionLabel)

internal fun AssistantViewModel.applyChannelSession(session: AssistantSessionResponse) =
    channelSessionClient.applyChannelSession(session)

internal suspend fun AssistantViewModel.sendDetailSupplementPayload(
    syncPayload: String,
    fallbackTaskId: String
): AssistantSessionResponse =
    channelSessionClient.sendDetailSupplementPayload(syncPayload, fallbackTaskId)

internal suspend fun AssistantViewModel.refreshLocationIfPermitted(
    force: Boolean,
    reason: String
): UserContextPayload? = userContextHolder.refreshLocationIfPermitted(force, reason)

internal suspend fun AssistantViewModel.resolveContactPayload(message: String): ContactResolutionPayload? =
    channelSessionClient.resolveContactPayload(message)

fun AssistantViewModel.onRetry() =
    runtimeLifecycleHandler.onRetry()

fun AssistantViewModel.onSelectSelectionOption(option: SelectionSheetOption) =
    userDecisionActionHandler.onSelectSelectionOption(option)

fun AssistantViewModel.onConfirm() =
    userDecisionActionHandler.onConfirm()

fun AssistantViewModel.completeDetailSupplement(
    contact: EffectiveTaskContact,
    detailSummaryText: String
) = detailSupplementActionHandler.completeDetailSupplement(contact, detailSummaryText)

internal fun AssistantViewModel.drainQueuedRecognizedTurn() =
    conversationSubmitActionHandler.drainQueuedRecognizedTurn()

internal fun AssistantViewModel.submitRecognizedTurn(
    text: String,
    structuredUnderstanding: StructuredAssistantUnderstanding? = null,
    assistantResponseText: String? = null
) = conversationSubmitActionHandler.submitRecognizedTurn(
    text = text,
    structuredUnderstanding = structuredUnderstanding,
    assistantResponseText = assistantResponseText
)

internal fun AssistantViewModel.applyInitialSession(session: AssistantSessionResponse) =
    sessionMapper.applyInitialSession(session)

internal fun AssistantViewModel.applyTextSession(session: AssistantSessionResponse) =
    sessionMapper.applyTextSession(session)

internal fun AssistantViewModel.applySession(session: AssistantSessionResponse) =
    sessionMapper.applySession(session)

internal fun AssistantViewModel.scheduleAutoResumeListening(delayMillis: Long) =
    sessionMapper.scheduleAutoResumeListening(delayMillis)

internal fun AssistantViewModel.estimateAssistantResumeDelay(session: AssistantSessionResponse): Long =
    sessionMapper.estimateAssistantResumeDelay(session)

internal fun AssistantViewModel.resetToIdleHome() =
    sessionMapper.resetToIdleHome()

internal fun AssistantViewModel.resolveActionableSummary(
    session: AssistantSessionResponse
): AssistantSessionActionableSummary? = sessionMapper.resolveActionableSummary(session)

internal fun AssistantViewModel.shouldEnterDetailSupplement(
    sceneType: String,
    taskId: String,
    actionable: AssistantSessionActionableSummary?
): Boolean = sessionMapper.shouldEnterDetailSupplement(sceneType, taskId, actionable)

internal fun AssistantViewModel.shouldForceSelectionDetailSupplement(
    session: AssistantSessionResponse,
    actionable: AssistantSessionActionableSummary?,
    selectionSheet: SelectionSheetData?,
    selectionContinuation: AssistantSessionPendingSelectionContinuation?
): Boolean = sessionMapper.shouldForceSelectionDetailSupplement(
    session,
    actionable,
    selectionSheet,
    selectionContinuation
)

internal fun AssistantViewModel.startDetailSupplement(
    session: AssistantSessionResponse,
    actionable: AssistantSessionActionableSummary
) = sessionMapper.startDetailSupplement(session, actionable)

internal fun AssistantViewModel.startDetailSupplementFromSelection(
    session: AssistantSessionResponse,
    targetName: String
) = sessionMapper.startDetailSupplementFromSelection(session, targetName)

internal fun AssistantViewModel.decorateSummaryWithSupplement(
    taskId: String,
    summary: SummaryData
): SummaryData = sessionMapper.decorateSummaryWithSupplement(taskId, summary)

internal fun AssistantViewModel.resolveSelectionSheet(session: AssistantSessionResponse): SelectionSheetData? =
    sessionMapper.resolveSelectionSheet(session)

internal fun AssistantViewModel.shouldSuppressSelectionSheet(
    taskId: String,
    sheet: SelectionSheetData
): Boolean = sessionMapper.shouldSuppressSelectionSheet(taskId, sheet)

internal fun AssistantViewModel.clearConsumedSelectionSheetIfTaskChanged(taskId: String) =
    sessionMapper.clearConsumedSelectionSheetIfTaskChanged(taskId)

internal fun AssistantViewModel.clearConsumedSelectionSheetSuppression() =
    sessionMapper.clearConsumedSelectionSheetSuppression()

internal fun AssistantViewModel.consumeVisibleSelectionSheet() {
    val state = internalUiState.value
    val sheet = state.selectionSheet
    if (sheet != null) {
        consumedSelectionSheetTaskId = state.taskId
        consumedSelectionSheetSignature = AssistantSessionSelectionSheetPolicy.signature(sheet)
    }
}

fun AssistantViewModel.resetTaskConversationForNewEntry(reason: String = "stop_voice_interaction") {
    AgentInitialSkillLaunchStore.clear()
    conversationSubmitActionHandler.clearSelectedContactForNextTurn()
    updatePureVoiceOcrContext(emptyList())
    taskConversationLifecycleHandler.resetForNewEntry(reason)
}

fun AssistantViewModel.interruptTaskConversationForUserClose(reason: String = "user_close") {
    conversationSubmitActionHandler.clearSelectedContactForNextTurn()
    taskConversationLifecycleHandler.interruptForUserClose(reason)
}

fun AssistantViewModel.pauseTaskConversationForBackground() =
    taskConversationLifecycleHandler.pauseForBackground()

fun AssistantViewModel.pauseTaskConversationAndResetLocalUi(
    reason: String = "navigate_back_pause",
    reloadConversations: Boolean = true
) {
    AgentInitialSkillLaunchStore.clear()
    conversationSubmitActionHandler.clearSelectedContactForNextTurn()
    taskConversationLifecycleHandler.pauseAndResetLocalUi(reason, reloadConversations)
}

fun AssistantViewModel.resumeTaskConversationForForeground() =
    conversationRestoreHandler.resumeTaskConversationForForeground()

internal suspend fun AssistantViewModel.syncConversationSnapshotForVoiceRecovery(
    sessionId: String,
    reason: String
): Boolean = conversationRestoreHandler.syncConversationSnapshotForVoiceRecovery(sessionId, reason)

@Suppress("UNUSED_PARAMETER")
fun AssistantViewModel.loadConversations(reason: String = "default") =
    taskConversationLifecycleHandler.loadConversations(reason)

fun AssistantViewModel.resumeConversation(sessionId: String, onFinished: (() -> Unit)? = null) {
    AgentInitialSkillLaunchStore.clear()
    conversationSubmitActionHandler.clearSelectedContactForNextTurn()
    conversationRestoreHandler.resumeConversation(sessionId, onFinished)
}

fun AssistantViewModel.returnToHomeFromResultPage() =
    taskConversationLifecycleHandler.returnToHomeFromResultPage()

internal fun AssistantViewModel.pushMergedHistoryToUi(tasks: List<TaskListItem>? = null) =
    taskCallHistoryController.pushMergedHistoryToUi(tasks)

fun AssistantViewModel.refreshHistory() =
    taskCallHistoryController.refreshHistory()
