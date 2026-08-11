package com.vvtech.aiassistant.features.assistant_session

import com.vvtech.aiassistant.core.model.AskQuestionsPayload
import com.vvtech.aiassistant.core.model.CallResultPayload
import com.vvtech.aiassistant.features.assistant.AssistantStage
import com.vvtech.aiassistant.features.assistant.ClarificationStep
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.TranscriptRole
import com.vvtech.aiassistant.features.assistant.VoiceRole
import com.vvtech.aiassistant.features.assistant_timeline.ConversationTimelineItem
import com.vvtech.aiassistant.features.assistant_timeline.ConversationTimelinePayload
import com.vvtech.aiassistant.features.assistant_timeline.TimelineOrderKey
import com.vvtech.aiassistant.domain.task.TaskReceiptItemState
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantConversationRestoreUiStateReducerTest {
    @Test
    fun restoresConversationStateAndClearsRuntimeFlags() {
        val questions = AskQuestionsPayload("补充信息", emptyList())
        val updated = AssistantConversationRestoreUiStateReducer.reduceRestoredConversationState(
            state = dirtyState(),
            snapshot = snapshot(
                steps = listOf(resumeStep(AssistantSessionResumeRole.User, "帮我订包间")),
                pendingToolCallId = "tool-1",
                agentQuestions = questions
            ),
            restoredStatus = "对话已恢复，点击继续说话",
            idleStatus = "idle"
        )

        assertEquals(AssistantStage.Clarifying, updated.stage)
        assertEquals(listOf(ClarificationStep(VoiceRole.User, "帮我订包间", "")), updated.clarificationSteps)
        assertEquals("session-1", updated.taskId)
        assertEquals("RUNNING", updated.taskStatus)
        assertEquals("对话已恢复，点击继续说话", updated.status)
        assertEquals("tool-1", updated.agentPendingToolCallId)
        assertEquals(questions, updated.agentQuestions)
        assertEquals("WAITING_FOR_TOOL", updated.executionStatus)
        assertRuntimeCleared(updated, expectLoadingCleared = false)
    }

    @Test
    fun restoresReadOnlyConversationWithoutStepsAsRestoredStatus() {
        val updated = AssistantConversationRestoreUiStateReducer.reduceRestoredConversationState(
            state = dirtyState(),
            snapshot = snapshot(steps = emptyList(), resolvedStatus = "COMPLETED", readOnly = true),
            restoredStatus = "对话已恢复，点击继续说话",
            idleStatus = "idle"
        )

        assertEquals(AssistantStage.Idle, updated.stage)
        assertEquals(emptyList<ClarificationStep>(), updated.clarificationSteps)
        assertEquals("COMPLETED", updated.taskStatus)
        assertEquals("对话已恢复，点击继续说话", updated.status)
        assertNull(updated.agentPendingToolCallId)
        assertFalse(updated.conversationContinuable)
        assertEquals("IDLE", updated.executionStatus)
    }

    @Test
    fun restoreUsesSnapshotConversationContinuableInsteadOfHardcodedValue() {
        val updated = AssistantConversationRestoreUiStateReducer.reduceVoiceRecoverySnapshotState(
            state = dirtyState().copy(conversationContinuable = true),
            snapshot = snapshot(
                steps = emptyList(),
                resolvedStatus = "WAITING_FOR_TOOL",
                conversationContinuable = false
            ),
            restoredStatus = "restored"
        )

        assertFalse(updated.conversationContinuable)
    }

    @Test
    fun restoredConversationRebuildsSingleCallResultTranscript() {
        val callResult = CallResultPayload(
            status = "COMPLETED",
            headline = "booking done",
            detail = "booking confirmed",
            metadata = mapOf(
                "reportCallOutcome" to "SUCCESS",
                "dialogueTranscript" to "assistant: hello\ncallee: confirmed"
            )
        )
        val updated = AssistantConversationRestoreUiStateReducer.reduceRestoredConversationState(
            state = dirtyState(),
            snapshot = snapshot(
                steps = emptyList(),
                resolvedStatus = "COMPLETED",
                readOnly = true,
                callResult = callResult
            ),
            restoredStatus = "restored",
            idleStatus = "idle"
        )

        assertEquals(callResult, updated.agentCallResult)
        assertNotNull(updated.agentCallResult)
        assertTrue(updated.callPageData.transcript.any {
            it.role == TranscriptRole.Assistant && it.text == "hello"
        })
        assertTrue(updated.callPageData.transcript.any {
            it.role == TranscriptRole.Remote && it.text == "confirmed"
        })
        assertTrue(updated.callPageData.transcript.any { it.role == TranscriptRole.Note })
    }

    @Test
    fun restoredConversationRebuildsTimelineCallResultPageDataAsSingleDisplaySource() {
        val callResult = CallResultPayload(
            status = "COMPLETED",
            headline = "booking done",
            detail = "booking confirmed",
            metadata = mapOf(
                "dialogueTranscript" to "AI：你好，问一下明天晚上有包房吗？\n对方：请问几位用餐？"
            )
        )

        val updated = AssistantConversationRestoreUiStateReducer.reduceRestoredConversationState(
            state = dirtyState(),
            snapshot = snapshot(
                steps = listOf(
                    AssistantSessionResumeStep(
                        role = AssistantSessionResumeRole.Assistant,
                        text = "done",
                        callResult = callResult
                    )
                ),
                resolvedStatus = "COMPLETED",
                readOnly = true,
                callResult = null
            ),
            restoredStatus = "restored",
            idleStatus = "idle"
        )

        assertEquals(callResult, updated.clarificationSteps.single().callResult)
        assertNull(updated.agentCallResult)
        assertTrue(updated.callPageData.transcript.any {
            it.role == TranscriptRole.Assistant && it.text == "你好，问一下明天晚上有包房吗？"
        })
        assertTrue(updated.callPageData.transcript.any {
            it.role == TranscriptRole.Remote && it.text == "请问几位用餐？"
        })
        assertTrue(updated.callPageData.transcript.any { it.role == TranscriptRole.Note })
    }

    @Test
    fun restoredTimelineIsTheSourceForLegacyStepsAndCallPageProjection() {
        val timeline = AssistantSessionTimelineRestoreSnapshot(
            listOf(
                ConversationTimelineItem(
                    itemId = "user-1",
                    orderKey = TimelineOrderKey(1),
                    payload = ConversationTimelinePayload.UserMessage("帮我订餐")
                ),
                ConversationTimelineItem(
                    itemId = "receipt-1",
                    orderKey = TimelineOrderKey(2),
                    payload = ConversationTimelinePayload.SingleCallReceipt(
                        callAttemptId = "call:1",
                        receipt = TaskReceiptItemState(
                            itemId = "receipt-1",
                            targetName = "新荣记",
                            status = "COMPLETED",
                            headline = "预订成功",
                            detail = "今晚八点"
                        )
                    )
                )
            )
        )
        val updated = AssistantConversationRestoreUiStateReducer.reduceRestoredConversationState(
            state = dirtyState(),
            snapshot = snapshot(
                steps = listOf(resumeStep(AssistantSessionResumeRole.User, "legacy must not win")),
                timeline = timeline
            ),
            restoredStatus = "restored",
            idleStatus = "idle"
        )

        assertEquals(timeline.timelineItems, updated.timelineItems)
        assertEquals("帮我订餐", updated.clarificationSteps.first().text)
        assertEquals("预订成功", updated.clarificationSteps.last().callResult?.headline)
        assertEquals("新荣记", updated.callPageData.name)
        assertNull(updated.agentCallResult)
    }

    @Test
    fun voiceRecoverySnapshotKeepsCurrentStepsWhenSnapshotIsEmpty() {
        val existingSteps = listOf(ClarificationStep(VoiceRole.Assistant, "请继续", ""))
        val updated = AssistantConversationRestoreUiStateReducer.reduceVoiceRecoverySnapshotState(
            state = dirtyState().copy(stage = AssistantStage.Idle, clarificationSteps = existingSteps),
            snapshot = snapshot(steps = emptyList()),
            restoredStatus = "对话已恢复，点击继续说话"
        )

        assertEquals(AssistantStage.Clarifying, updated.stage)
        assertEquals(existingSteps, updated.clarificationSteps)
        assertEquals("对话已恢复，点击继续说话", updated.status)
        assertRuntimeCleared(updated, expectLoadingCleared = true)
    }

    @Test
    fun failureAndForegroundReducersKeepExistingFallbackSemantics() {
        val foregroundPlaying = AssistantConversationRestoreUiStateReducer.reduceForegroundResumeState(
            state = Index9AssistantUiState(voiceBackgroundPaused = true, voiceManuallyPaused = true, apiTtsPlaying = true),
            listeningStatus = "listening",
            restoredStatus = "restored"
        )
        assertFalse(foregroundPlaying.voiceBackgroundPaused)
        assertFalse(foregroundPlaying.voiceManuallyPaused)
        assertEquals("listening", foregroundPlaying.status)

        val foregroundWithSteps = AssistantConversationRestoreUiStateReducer.reduceForegroundResumeState(
            state = Index9AssistantUiState(
                voiceBackgroundPaused = true,
                clarificationSteps = listOf(ClarificationStep(VoiceRole.User, "继续", ""))
            ),
            listeningStatus = "listening",
            restoredStatus = "restored"
        )
        assertEquals("restored", foregroundWithSteps.status)

        val loadFailure = AssistantConversationRestoreUiStateReducer.reduceVoiceRecoveryLoadFailureState(
            state = dirtyState().copy(clarificationSteps = foregroundWithSteps.clarificationSteps),
            tapMicToContinueStatus = "tap mic"
        )
        assertEquals("tap mic", loadFailure.status)
        assertFalse(loadFailure.loading)
        assertFalse(loadFailure.voiceConnecting)
        assertFalse(loadFailure.listening)
        assertFalse(loadFailure.processingTurn)
        assertNull(loadFailure.error)

        val restoreFailure = AssistantConversationRestoreUiStateReducer.reduceRestoreFailureState(
            state = Index9AssistantUiState(),
            failureStatus = "恢复对话失败"
        )
        assertEquals(AssistantStage.Clarifying, restoreFailure.stage)
        assertEquals(emptyList<ClarificationStep>(), restoreFailure.clarificationSteps)
        assertEquals("恢复对话失败", restoreFailure.status)
    }

    @Test
    fun restoreHandlerDelegatesUiStateMaintenance() {
        val oldHandler =
            File("src/main/java/com/vvtech/aiassistant/features/assistant/viewmodel/ConversationRestoreHandler.kt")
        val handler =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_session/ConversationRestoreHandler.kt")
                .readText(Charsets.UTF_8)
        val runtimeHandler =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_session/AssistantConversationRestoreRuntimeHandler.kt")
                .readText(Charsets.UTF_8)
        val stateReader =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_session/AssistantConversationRestoreStateReader.kt")
                .readText(Charsets.UTF_8)
        val loader =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_session/AssistantConversationRestoreSnapshotLoader.kt")
                .readText(Charsets.UTF_8)
        val applier =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_session/AssistantConversationRestoreSnapshotApplier.kt")
                .readText(Charsets.UTF_8)
        val stateHolder =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_session/AssistantConversationRestoreUiStateHolder.kt")
                .readText(Charsets.UTF_8)
        val restoreUseCase =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_session/AssistantConversationRestoreUseCase.kt")
                .readText(Charsets.UTF_8)
        val reducer =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_session/AssistantConversationRestoreUiStateReducer.kt")
                .readText(Charsets.UTF_8)

        assertFalse(oldHandler.exists())
        assertTrue(handler.contains("package com.vvtech.aiassistant.features.assistant_session"))
        assertTrue(handler.contains("AssistantConversationRestoreSnapshotApplier("))
        assertTrue(handler.contains("AssistantConversationRestoreUiStateHolder(deps.uiState)"))
        assertTrue(handler.contains("AssistantConversationRestoreStateReader(deps.uiState)"))
        assertTrue(handler.contains("AssistantConversationRestoreSnapshotLoader("))
        assertTrue(handler.contains("AssistantConversationRestoreRuntimeHandler("))
        assertTrue(handler.contains("AssistantConversationRestoreRuntimeDeps("))
        assertTrue(handler.contains("runtimeHandler.resumeTaskConversationForForeground()"))
        assertTrue(handler.contains("runtimeHandler.syncConversationSnapshotForVoiceRecovery(sessionId, reason)"))
        assertTrue(handler.contains("runtimeHandler.resumeConversation(sessionId, onFinished)"))
        assertFalse(handler.contains("deps.restoreUseCase.loadSnapshot(sessionId, ::rawStatusFor)"))
        assertFalse(handler.contains("repository.getConversation(sessionId)"))
        assertTrue(restoreUseCase.contains("repository.getConversation(sessionId)"))
        assertTrue(restoreUseCase.contains("buildAssistantConversationRestoreSnapshot("))
        assertFalse(handler.contains("AppFileLogger.w"))
        assertFalse(handler.contains("onFinished?.invoke()"))
        assertFalse(handler.contains("private fun applyConversationSnapshot"))
        assertFalse(handler.contains("private fun rawStatusFor"))
        assertTrue(runtimeHandler.contains("idleStatus = callbacks.idleStatus()"))
        assertTrue(runtimeHandler.contains("internal data class AssistantConversationRestoreRuntimeDeps"))
        assertTrue(runtimeHandler.contains("val stateReader: AssistantConversationRestoreStateReader"))
        assertTrue(runtimeHandler.contains("deps.stateReader.currentState()"))
        assertTrue(runtimeHandler.contains("val scope: CoroutineScope"))
        assertFalse(runtimeHandler.contains("MutableStateFlow<Index9AssistantUiState>"))
        assertFalse(runtimeHandler.contains("deps.uiState.value"))
        assertFalse(runtimeHandler.contains("RestoreHandlerDeps"))
        assertFalse(runtimeHandler.contains("restoreUseCase"))
        assertFalse(runtimeHandler.contains("conversationList"))
        assertFalse(runtimeHandler.contains("taskRestoreStateHolder"))
        assertTrue(runtimeHandler.contains("AppFileLogger.w"))
        assertTrue(runtimeHandler.contains("onFinished?.invoke()"))
        assertTrue(runtimeHandler.contains("snapshotApplier.applyRestoredConversation"))
        assertTrue(runtimeHandler.contains("snapshotApplier.applyVoiceRecoverySnapshot"))
        assertTrue(runtimeHandler.contains("snapshotApplier.applyVoiceRecoveryLoadFailure"))
        assertTrue(runtimeHandler.contains("snapshotApplier.applyForegroundResume"))
        assertFalse(handler.contains("features.assistant.viewmodel.DefaultIdleStatus"))
        assertFalse(handler.contains("AssistantConversationRestoreUiStateReducer."))
        assertFalse(handler.contains("AssistantSessionResumeRole"))
        assertFalse(handler.contains("toClarificationStep"))
        assertTrue(runtimeHandler.contains("snapshotLoader.load(sessionId)"))
        assertFalse(runtimeHandler.contains("deps.restoreUseCase.loadSnapshot(sessionId, ::rawStatusFor)"))
        assertFalse(runtimeHandler.contains("private fun rawStatusFor"))
        assertTrue(loader.contains("restoreUseCase.loadSnapshot(sessionId, ::rawStatusFor)"))
        assertTrue(loader.contains("conversationList.value.firstOrNull"))
        assertTrue(applier.contains("private val uiStateHolder: AssistantConversationRestoreUiStateHolder"))
        assertTrue(applier.contains("uiStateHolder.applyRestoredConversation"))
        assertTrue(applier.contains("uiStateHolder.applyVoiceRecoverySnapshot"))
        assertTrue(applier.contains("uiStateHolder.applyVoiceRecoveryLoadFailure"))
        assertTrue(applier.contains("uiStateHolder.applyForegroundResume"))
        assertTrue(applier.contains("uiStateHolder.applyRestoreFailure"))
        assertFalse(applier.contains("MutableStateFlow<Index9AssistantUiState>"))
        assertFalse(applier.contains("uiState.update"))
        assertFalse(applier.contains("AssistantConversationRestoreUiStateReducer."))
        assertTrue(applier.contains("taskRestoreStateHolder.updateConversationCardStatus"))
        assertTrue(stateHolder.contains("MutableStateFlow<Index9AssistantUiState>"))
        assertTrue(stateHolder.contains("uiState.update"))
        assertTrue(stateHolder.contains("AssistantConversationRestoreUiStateReducer.reduceRestoredConversationState"))
        assertTrue(stateHolder.contains("AssistantConversationRestoreUiStateReducer.reduceVoiceRecoverySnapshotState"))
        assertTrue(stateHolder.contains("AssistantConversationRestoreUiStateReducer.reduceVoiceRecoveryLoadFailureState"))
        assertTrue(stateHolder.contains("AssistantConversationRestoreUiStateReducer.reduceForegroundResumeState"))
        assertTrue(stateHolder.contains("AssistantConversationRestoreUiStateReducer.reduceRestoreFailureState"))
        assertTrue(stateReader.contains("StateFlow<Index9AssistantUiState>"))
        assertTrue(stateReader.contains("fun currentState(): Index9AssistantUiState = uiState.value"))
        assertFalse(stateReader.contains("MutableStateFlow<Index9AssistantUiState>"))
        assertTrue(reducer.contains("fun restoreStepsToClarificationSteps"))
        assertTrue(reducer.contains("fun reduceRestoredConversationState"))
    }

    private fun dirtyState(): Index9AssistantUiState {
        return Index9AssistantUiState(
            loading = true,
            voiceConnecting = true,
            voiceActive = true,
            listening = true,
            processingTurn = true,
            voiceManuallyPaused = true,
            voiceBackgroundPaused = true,
            liveUserTranscript = "user",
            liveAssistantTranscript = "assistant",
            apiAsrListening = true,
            apiAsrPartialText = "partial",
            apiTtsPlaying = true,
            localTtsSpeaking = true,
            error = "old",
            unresolvedTaskErrorStatus = "FAILED",
            taskErrorRecoveryInProgress = true
        )
    }

    private fun snapshot(
        steps: List<AssistantSessionResumeStep>,
        resolvedStatus: String = "RUNNING",
        readOnly: Boolean = false,
        pendingToolCallId: String? = null,
        agentQuestions: AskQuestionsPayload? = null,
        callResult: CallResultPayload? = null,
        timeline: AssistantSessionTimelineRestoreSnapshot = AssistantSessionTimelineRestoreSnapshot(emptyList()),
        conversationContinuable: Boolean = !readOnly
    ): AssistantConversationRestoreSnapshot {
        return AssistantConversationRestoreSnapshot(
            sessionId = "session-1",
            title = "Target Restaurant",
            sceneType = "RESTAURANT_BOOKING",
            resolvedStatus = resolvedStatus,
            steps = steps,
            timeline = timeline,
            readOnly = readOnly,
            conversationContinuable = conversationContinuable,
            pendingToolCallId = pendingToolCallId,
            agentQuestions = agentQuestions,
            agentCallSpec = null,
            callResult = callResult
        )
    }

    private fun resumeStep(
        role: AssistantSessionResumeRole,
        text: String
    ): AssistantSessionResumeStep {
        return AssistantSessionResumeStep(role = role, text = text)
    }

    private fun assertRuntimeCleared(
        state: Index9AssistantUiState,
        expectLoadingCleared: Boolean
    ) {
        if (expectLoadingCleared) {
            assertFalse(state.loading)
        }
        assertFalse(state.voiceConnecting)
        assertFalse(state.voiceActive)
        assertFalse(state.listening)
        assertFalse(state.processingTurn)
        assertFalse(state.voiceManuallyPaused)
        assertFalse(state.voiceBackgroundPaused)
        assertFalse(state.apiAsrListening)
        assertNull(state.apiAsrPartialText)
        assertFalse(state.apiTtsPlaying)
        assertFalse(state.localTtsSpeaking)
        assertNull(state.liveUserTranscript)
        assertNull(state.liveAssistantTranscript)
        assertNull(state.error)
        assertNull(state.unresolvedTaskErrorStatus)
        assertFalse(state.taskErrorRecoveryInProgress)
    }
}
