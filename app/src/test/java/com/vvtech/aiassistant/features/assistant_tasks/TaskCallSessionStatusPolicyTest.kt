package com.vvtech.aiassistant.features.assistant_tasks

import com.vvtech.aiassistant.core.model.CallSessionStatusResponse
import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TaskCallSessionStatusPolicyTest {
    @Test
    fun statusFactsDetectHumanTakeoverAndNote() {
        val facts = taskCallSessionStatusFacts(
            response = response(handoffMode = "HUMAN_ACTIVE", callState = "CONNECTED"),
            appendNote = true,
            activeTakeoverCallId = null,
            nowElapsedMillis = 1000L,
            takeoverStateProtectUntilElapsed = 0L
        )

        assertTrue(facts.humanMode)
        assertFalse(facts.humanRequested)
        assertFalse(facts.terminalCallState)
        assertFalse(facts.protectTakeoverState)
        assertTrue(facts.shouldStartTakeoverAudio)
        assertFalse(facts.shouldStopTakeoverAudio)
        assertTrue(facts.note == "已切换为人工接管")
    }

    @Test
    fun statusFactsProtectRegressiveConnectedAiStatusDuringTakeover() {
        val facts = taskCallSessionStatusFacts(
            response = response(handoffMode = "AI_ACTIVE", callState = "CONNECTED"),
            appendNote = false,
            activeTakeoverCallId = "call-1",
            nowElapsedMillis = 1000L,
            takeoverStateProtectUntilElapsed = 2000L
        )

        assertFalse(facts.humanMode)
        assertFalse(facts.humanRequested)
        assertFalse(facts.terminalCallState)
        assertTrue(facts.protectTakeoverState)
        assertFalse(facts.shouldStartTakeoverAudio)
        assertFalse(facts.shouldStopTakeoverAudio)
    }

    @Test
    fun statusFactsStopTakeoverAudioOnTerminalCallState() {
        val facts = taskCallSessionStatusFacts(
            response = response(handoffMode = "COMPLETED", callState = "ENDED"),
            appendNote = false,
            activeTakeoverCallId = "call-1",
            nowElapsedMillis = 3000L,
            takeoverStateProtectUntilElapsed = 2000L
        )

        assertTrue(facts.terminalCallState)
        assertTrue(facts.shouldStopTakeoverAudio)
        assertFalse(facts.protectTakeoverState)
    }

    @Test
    fun deferTerminalStatusUntilAgentOutcomeWhenTransportLooksSuccessful() {
        val shouldDefer = shouldDeferTaskCallSessionTerminalStatus(
            response = response(
                taskId = "task-1",
                callState = "ENDED",
                handoffMode = "COMPLETED",
                resultCode = ""
            ),
            context = TaskCallSessionAgentOutcomeDeferContext(
                currentTaskId = "task-1",
                agentSessionId = "task-1",
                hasAgentCallResult = false,
                processingTurn = true,
                pendingAiCallLaunch = false
            )
        )

        assertTrue(shouldDefer)
    }

    @Test
    fun deferNoAnswerFailureUntilAgentOutcome() {
        val shouldDefer = shouldDeferTaskCallSessionTerminalStatus(
            response = response(
                taskId = "task-1",
                callState = "FAILED",
                handoffMode = "FAILED",
                resultCode = ""
            ),
            context = TaskCallSessionAgentOutcomeDeferContext(
                currentTaskId = "task-1",
                agentSessionId = "task-1",
                hasAgentCallResult = false,
                processingTurn = true,
                pendingAiCallLaunch = false
            )
        )

        assertTrue(shouldDefer)
    }

    @Test
    fun deferTerminalStatusRequiresMatchingAgentSessionButNotTransientRuntimeFlags() {
        val baseResponse = response(
            taskId = "task-1",
            callState = "ENDED",
            handoffMode = "COMPLETED",
            resultCode = ""
        )

        assertFalse(
            shouldDeferTaskCallSessionTerminalStatus(
                response = baseResponse,
                context = TaskCallSessionAgentOutcomeDeferContext(
                    currentTaskId = "task-1",
                    agentSessionId = "other-task",
                    hasAgentCallResult = false,
                    processingTurn = true,
                    pendingAiCallLaunch = false
                )
            )
        )
        assertFalse(
            shouldDeferTaskCallSessionTerminalStatus(
                response = baseResponse.copy(resultCode = "AGENT_SUCCESS"),
                context = TaskCallSessionAgentOutcomeDeferContext(
                    currentTaskId = "task-1",
                    agentSessionId = "task-1",
                    hasAgentCallResult = false,
                    processingTurn = true,
                    pendingAiCallLaunch = false
                )
            )
        )
        assertFalse(
            shouldDeferTaskCallSessionTerminalStatus(
                response = baseResponse,
                context = TaskCallSessionAgentOutcomeDeferContext(
                    currentTaskId = "task-1",
                    agentSessionId = "task-1",
                    hasAgentCallResult = true,
                    processingTurn = true,
                    pendingAiCallLaunch = false
                )
            )
        )
        assertTrue(
            shouldDeferTaskCallSessionTerminalStatus(
                response = baseResponse,
                context = TaskCallSessionAgentOutcomeDeferContext(
                    currentTaskId = "task-1",
                    agentSessionId = "task-1",
                    hasAgentCallResult = false,
                    processingTurn = false,
                    pendingAiCallLaunch = false
                )
            )
        )
    }

    @Test
    fun callActionHandlerDelegatesStatusRulesToTaskPolicy() {
        val handler =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/viewmodel/CallActionHandler.kt")
                .readText(Charsets.UTF_8)
        val controller =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_tasks/TaskCallSessionStatusApplyController.kt")
                .readText(Charsets.UTF_8)
        val policy =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_tasks/TaskCallSessionStatusPolicy.kt")
                .readText(Charsets.UTF_8)

        assertTrue(handler.contains("callSessionStatusApplyController.apply(response, appendNote)"))
        assertFalse(handler.contains("taskCallSessionStatusFacts("))
        assertFalse(handler.contains("shouldDeferTaskCallSessionTerminalStatus("))
        assertTrue(controller.contains("taskCallSessionStatusFacts("))
        assertTrue(controller.contains("shouldDeferTaskCallSessionTerminalStatus("))
        assertFalse(handler.contains("val humanMode = response.handoffMode.equals"))
        assertFalse(handler.contains("val terminalCallState = response.callState.equals"))
        assertFalse(handler.contains("resultCode.startsWith(\"AGENT_\")"))
        assertFalse(handler.contains("SystemClock.elapsedRealtime() < viewModel.takeoverStateProtectUntilElapsed"))

        assertTrue(policy.contains("protectTakeoverState"))
        assertTrue(policy.contains("shouldDeferTaskCallSessionTerminalStatus"))
        assertTrue(policy.contains("resultCode.startsWith(\"AGENT_\")"))
    }

    private fun response(
        taskId: String = "task-1",
        callId: String = "call-1",
        callState: String = "CONNECTED",
        handoffMode: String = "AI_ACTIVE",
        resultCode: String = ""
    ): CallSessionStatusResponse {
        return CallSessionStatusResponse(
            callId = callId,
            taskId = taskId,
            sceneType = "FOOD_ORDERING",
            targetName = "北海渔村",
            phoneNumber = "0755-86966889",
            callState = callState,
            handoffMode = handoffMode,
            backendCallEnabled = true,
            handoffSupported = true,
            appRtcRequired = false,
            dialogueDetail = "",
            statusMessage = "通话进行中",
            resultCode = resultCode,
            updatedAt = "2026-05-12T05:40:52"
        )
    }

    private companion object {
        fun sourceFile(relativePath: String): File {
            return generateSequence(File(".").absoluteFile) { it.parentFile }
                .map { File(it, relativePath) }
                .first { it.exists() }
        }
    }
}
