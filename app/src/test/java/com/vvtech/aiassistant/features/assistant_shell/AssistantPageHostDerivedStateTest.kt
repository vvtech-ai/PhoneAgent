package com.vvtech.aiassistant.features.assistant_shell

import androidx.compose.ui.unit.dp
import com.vvtech.aiassistant.features.assistant.ClarificationStep
import com.vvtech.aiassistant.features.assistant.FinalPage
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.VoiceRole
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantPageHostDerivedStateTest {
    @Test
    fun topLevelPagesDoNotReserveOpaqueBottomInset() {
        listOf(FinalPage.Contacts, FinalPage.Calls, FinalPage.Tasks).forEach { page ->
            val derived = deriveAssistantPageHostState(
                AssistantPageHostDerivedStateInput(
                    currentPage = page,
                    assistantUiState = Index9AssistantUiState(),
                    localTaskStarted = false,
                    localTaskUserText = "",
                    localAiThinking = false,
                    localAiReplyVisible = false,
                    useSingleFlowConversation = false,
                    resultCallIdFallback = null
                )
            )

            assertEquals("$page should render behind the translucent navigation.", 0.dp, derived.pageBottomInset)
        }
    }

    @Test
    fun bottomTabsWaitUntilSingleFlowExitContentIsDisposed() {
        val exiting = deriveAssistantPageHostState(
            topLevelInput(singleFlowTransitionContentVisible = true)
        )
        val settled = deriveAssistantPageHostState(
            topLevelInput(singleFlowTransitionContentVisible = false)
        )

        assertFalse(exiting.showBottomTabs)
        assertTrue(settled.showBottomTabs)
    }

    @Test
    fun nonSingleFlowUsesBackendTaskVisibilityAndAssistantState() {
        val derived = deriveAssistantPageHostState(
            AssistantPageHostDerivedStateInput(
                currentPage = FinalPage.Home,
                assistantUiState = Index9AssistantUiState(
                    clarificationSteps = listOf(
                        ClarificationStep(VoiceRole.User, "给小明打电话", status = ""),
                        ClarificationStep(VoiceRole.Assistant, "好的", status = "")
                    ),
                    processingTurn = true,
                    currentCallId = "call-1"
                ),
                localTaskStarted = false,
                localTaskUserText = "local text",
                localAiThinking = false,
                localAiReplyVisible = false,
                useSingleFlowConversation = false,
                resultCallIdFallback = "fallback-call"
            )
        )

        assertTrue(derived.showBottomTabs)
        assertTrue(derived.effectiveTaskStarted)
        assertEquals("给小明打电话", derived.effectiveTaskUserText)
        assertTrue(derived.effectiveAiThinking)
        assertTrue(derived.effectiveAiReplyVisible)
        assertEquals("call-1", derived.resultCallId)
    }

    @Test
    fun singleFlowKeepsLocalTaskStartedButStillUsesBackendText() {
        val derived = deriveAssistantPageHostState(
            AssistantPageHostDerivedStateInput(
                currentPage = FinalPage.SingleFlow,
                assistantUiState = Index9AssistantUiState(
                    clarificationSteps = listOf(
                        ClarificationStep(VoiceRole.User, "订个包间", status = "")
                    ),
                    taskId = "task-1"
                ),
                localTaskStarted = false,
                localTaskUserText = "local text",
                localAiThinking = false,
                localAiReplyVisible = false,
                useSingleFlowConversation = true,
                resultCallIdFallback = null
            )
        )

        assertFalse(derived.effectiveTaskStarted)
        assertEquals("订个包间", derived.effectiveTaskUserText)
    }

    @Test
    fun blankCallIdFallsBackToProvidedResultCallId() {
        val derived = deriveAssistantPageHostState(
            AssistantPageHostDerivedStateInput(
                currentPage = FinalPage.Result,
                assistantUiState = Index9AssistantUiState(currentCallId = ""),
                localTaskStarted = false,
                localTaskUserText = "",
                localAiThinking = false,
                localAiReplyVisible = false,
                useSingleFlowConversation = true,
                resultCallIdFallback = "mock-call"
            )
        )

        assertEquals("mock-call", derived.resultCallId)
    }

    private fun topLevelInput(
        singleFlowTransitionContentVisible: Boolean
    ) = AssistantPageHostDerivedStateInput(
        currentPage = FinalPage.Tasks,
        assistantUiState = Index9AssistantUiState(),
        localTaskStarted = false,
        localTaskUserText = "",
        localAiThinking = false,
        localAiReplyVisible = false,
        useSingleFlowConversation = true,
        resultCallIdFallback = null,
        singleFlowTransitionContentVisible = singleFlowTransitionContentVisible
    )
}
