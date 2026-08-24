package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.CallSpecPayload
import com.vvtech.aiassistant.features.assistant.CallPageData
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.TranscriptLine
import com.vvtech.aiassistant.features.assistant.TranscriptRole
import java.io.File
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AgentStreamConfirmCallHandlerTest {
    @Test
    fun manualConfirmPreservesSideEffectOrderAndRequestFields() = runBlocking {
        val harness = Harness(scope = this, voiceMode = true)

        harness.handler.onConfirm(auto = false)

        assertEquals(
            listOf(
                "pending:true",
                "log:onAgentCallConfirm auto=false sessionId=s1 beforeUpdate snapshot",
                "seed:正在拨打电话...",
                "user:已确认拨打",
                "state:正在拨打电话...:true",
                "log:onAgentCallConfirm showAiCallPage=true sessionId=s1 afterUpdate snapshot",
                "suspend:agent_call_confirm",
                "poll:start",
                "placeholder:9",
                "submit:confirm_call"
            ),
            harness.events
        )
        assertEquals(
            CapturedRequest(
                sessionId = "s1",
                actionId = "confirm_call",
                contextReason = "agent_confirm_call",
                logAction = "confirm_call",
                channel = "voice",
                userId = "user-1",
                placeholderIndex = 9,
                failureMessage = "拨打失败"
            ),
            harness.capturedRequest
        )
        assertTrue(harness.pendingLaunch)
        assertTrue(harness.state.showAiCallPage)
        assertNull(harness.state.agentCallSpec)
        assertTrue(harness.latestCallPageSeed.transcript.any { it.text == "已有备注" })
        assertTrue(harness.latestCallPageSeed.transcript.any { it.text == "通话任务字段：餐厅：北海渔村" })
    }

    @Test
    fun pendingLaunchSkipsConfirm() = runBlocking {
        val harness = Harness(scope = this, pendingLaunch = true)

        harness.handler.onConfirm()

        assertTrue(harness.events.isEmpty())
        assertNull(harness.capturedRequest)
    }

    @Test
    fun actionFailureWithoutActiveCallClearsPendingStopsPollingAndRecoversCallPage() = runBlocking {
        val harness = Harness(
            scope = this,
            failSubmit = true,
            state = baseState().copy(showAiCallPage = true, handoffInFlight = true)
        )

        harness.handler.onConfirm()

        assertFalse(harness.pendingLaunch)
        assertTrue(harness.events.contains("poll:stop"))
        assertTrue(
            harness.events.contains(
                "log:onAgentCallConfirm failed sessionId=s1 keepCallPage=false message=boom snapshot"
            )
        )
        assertFalse(harness.state.showAiCallPage)
        assertFalse(harness.state.handoffInFlight)
    }

    @Test
    fun actionFailureWithActiveCallKeepsPendingPollingAndCallPage() = runBlocking {
        val harness = Harness(
            scope = this,
            failSubmit = true,
            state = baseState().copy(
                showAiCallPage = true,
                handoffInFlight = true,
                currentCallId = "call-active"
            )
        )

        harness.handler.onConfirm()

        assertTrue(harness.pendingLaunch)
        assertFalse(harness.events.contains("poll:stop"))
        assertTrue(
            harness.events.contains(
                "log:onAgentCallConfirm failed sessionId=s1 keepCallPage=true message=boom snapshot"
            )
        )
        assertTrue(harness.state.showAiCallPage)
        assertEquals("call-active", harness.state.currentCallId)
    }

    @Test
    fun autoConfirmRunsOnlyWhenGateMatches() = runBlocking {
        val harness = Harness(scope = this)

        harness.handler.scheduleAutoConfirm()
        delay(1550)

        assertEquals("submit:confirm_call", harness.events.last())
        assertEquals("text", harness.capturedRequest?.channel)
    }

    @Test
    fun autoConfirmCanBeCancelledBeforeDelay() = runBlocking {
        val harness = Harness(scope = this)

        harness.handler.scheduleAutoConfirm()
        harness.handler.cancelAutoConfirm()
        delay(1550)

        assertTrue(harness.events.isEmpty())
        assertNull(harness.capturedRequest)
    }

    @Test
    fun agentStreamHandlerDelegatesConfirmCallFlow() {
        val agentStreamHandler =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamHandler.kt")
                .readText(Charsets.UTF_8)
        val actionGraph =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamActionRuntimeGraph.kt")
                .readText(Charsets.UTF_8)
        val confirmHandler =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamConfirmCallHandler.kt")
                .readText(Charsets.UTF_8)

        assertTrue(agentStreamHandler.contains("AgentStreamActionRuntimeGraph("))
        assertTrue(agentStreamHandler.contains("actionGraph.onAgentCallConfirm(auto)"))
        assertTrue(agentStreamHandler.contains("actionGraph.cancelAutoConfirm()"))
        assertTrue(actionGraph.contains("AgentStreamConfirmCallHandler("))
        assertTrue(actionGraph.contains("confirmCallHandler.onConfirm(auto)"))
        assertTrue(actionGraph.contains("confirmCallHandler.scheduleAutoConfirm()"))
        assertTrue(actionGraph.contains("confirmCallHandler.cancelAutoConfirm()"))
        assertFalse(agentStreamHandler.contains("AgentStreamConfirmCallLaunchPolicy.plan("))
        assertFalse(agentStreamHandler.contains("autoConfirmCallJob"))

        assertTrue(confirmHandler.contains("AgentStreamConfirmCallLaunchPolicy.plan("))
        assertTrue(confirmHandler.contains("delay(AutoConfirmDelayMs)"))
        assertFalse(confirmHandler.contains("AssistantViewModel"))
        assertFalse(confirmHandler.contains("AssistantRepository"))
    }

    private class Harness(
        scope: CoroutineScope,
        var state: Index9AssistantUiState = baseState(),
        private val sessionId: String? = "s1",
        var latestCallPageSeed: CallPageData = callPageSeed(),
        var pendingLaunch: Boolean = false,
        private val voiceMode: Boolean = false,
        private val failSubmit: Boolean = false
    ) {
        val events = mutableListOf<String>()
        var capturedRequest: CapturedRequest? = null

        val handler = AgentStreamConfirmCallHandler(
            runtime = AgentStreamConfirmCallRuntime(
                stateProvider = { state },
                sessionIdProvider = { sessionId },
                latestCallPageSeedProvider = { latestCallPageSeed },
                isPendingLaunch = { pendingLaunch },
                setPendingLaunch = { pending ->
                    pendingLaunch = pending
                    events += "pending:$pending"
                },
                isVoiceMode = { voiceMode },
                scope = scope,
                userIdProvider = { "user-1" },
                languageCodeProvider = { "zh-CN" },
                responseLanguageProvider = { "Simplified Chinese" }
            ),
            callbacks = AgentStreamConfirmCallCallbacks(
                setLatestCallPageSeed = { seed ->
                    latestCallPageSeed = seed
                    events += "seed:${seed.status}"
                },
                appendUserStep = { text -> events += "user:$text" },
                updateState = { reducer ->
                    state = reducer(state)
                    events += "state:${state.status}:${state.showAiCallPage}"
                },
                logCallPage = { message -> events += "log:$message" },
                audioGateSnapshot = { "snapshot" },
                suspendDialogAudioForCall = { reason -> events += "suspend:$reason" },
                startCallSessionPolling = { events += "poll:start" },
                stopCallSessionPolling = { events += "poll:stop" },
                appendAssistantPlaceholder = {
                    events += "placeholder:9"
                    9
                },
                submitAction = { request, onFailureBeforeHandle, beforeRecover ->
                    capturedRequest = CapturedRequest(
                        sessionId = request.sessionId,
                        actionId = request.actionId,
                        contextReason = request.contextReason,
                        logAction = request.logAction,
                        channel = request.channel,
                        userId = request.userId,
                        placeholderIndex = request.placeholderIndex,
                        failureMessage = request.failureMessage
                    )
                    events += "submit:${request.actionId}"
                    if (failSubmit) {
                        val throwable = IllegalStateException("boom")
                        onFailureBeforeHandle?.invoke(throwable)
                        beforeRecover?.invoke()
                    }
                    scope.launch { }
                }
            )
        )
    }

    private data class CapturedRequest(
        val sessionId: String,
        val actionId: String,
        val contextReason: String,
        val logAction: String,
        val channel: String?,
        val userId: String,
        val placeholderIndex: Int,
        val failureMessage: String
    )

    private companion object {
        fun baseState(): Index9AssistantUiState {
            return Index9AssistantUiState(
                agentCallSpec = CallSpecPayload(
                    phoneNumber = "010-12345678",
                    scene = "restaurant",
                    targetName = "北海渔村",
                    primaryGoal = "订包间",
                    summaryLines = listOf("needPrivateRoom:true")
                )
            )
        }

        fun callPageSeed(): CallPageData {
            return CallPageData(
                name = "北海渔村",
                sub = "订包间",
                status = "准备拨打",
                transcript = listOf(
                    TranscriptLine(TranscriptRole.Note, "已有备注"),
                    TranscriptLine(TranscriptRole.Assistant, "旧助手转写")
                )
            )
        }

        fun sourceFile(path: String): File {
            return listOf(
                File(path),
                File("android/app/$path")
            ).first { it.exists() }
        }
    }
}
