package com.vvtech.aiassistant.features.assistant_shell

import com.vvtech.aiassistant.features.assistant.FinalPage
import org.junit.Assert.assertEquals
import org.junit.Test

class AssistantTaskNavigationActionsTest {
    @Test
    fun resumeCurrentConversationRestoresSessionBeforeEnteringSingleFlowWhenLocalStepsAreEmpty() {
        val recorder = TaskNavigationRecorder()

        resumeCurrentAssistantTaskConversation(
            state = AssistantTaskPageNavigationState(
                activeSessionId = "session-1",
                hasLocalConversationSteps = false,
                useSingleFlowConversation = true
            ),
            callbacks = recorder.callbacks
        )

        assertEquals(listOf("resume:session-1", "single:false"), recorder.events)
    }

    @Test
    fun resumeCurrentConversationEntersSingleFlowDirectlyWhenLocalStepsExist() {
        val recorder = TaskNavigationRecorder()

        resumeCurrentAssistantTaskConversation(
            state = AssistantTaskPageNavigationState(
                activeSessionId = "session-1",
                hasLocalConversationSteps = true,
                useSingleFlowConversation = true
            ),
            callbacks = recorder.callbacks
        )

        assertEquals(listOf("single:false"), recorder.events)
    }

    @Test
    fun openHistoryConversationRestoresThenEntersSingleFlow() {
        val recorder = TaskNavigationRecorder()

        openAssistantTaskConversation("history-1", recorder.callbacks)

        assertEquals(listOf("resume:history-1", "single:false"), recorder.events)
    }

    @Test
    fun openTaskResultUsesSingleFlowResultSurface() {
        val recorder = TaskNavigationRecorder()

        openAssistantTaskResult(recorder.callbacks)

        assertEquals(listOf("single:false"), recorder.events)
    }

    @Test
    fun followUpUsesVoiceSingleFlowWhenSingleFlowModeIsEnabled() {
        val recorder = TaskNavigationRecorder()

        followUpAssistantTask(
            state = AssistantTaskPageNavigationState(
                activeSessionId = null,
                hasLocalConversationSteps = false,
                useSingleFlowConversation = true
            ),
            callbacks = recorder.callbacks
        )

        assertEquals(listOf("open::true"), recorder.events)
    }

    @Test
    fun followUpFallsBackToAssistantPageWhenSingleFlowModeIsDisabled() {
        val recorder = TaskNavigationRecorder()

        followUpAssistantTask(
            state = AssistantTaskPageNavigationState(
                activeSessionId = null,
                hasLocalConversationSteps = false,
                useSingleFlowConversation = false
            ),
            callbacks = recorder.callbacks
        )

        assertEquals(listOf("page:Assistant"), recorder.events)
    }
}

private class TaskNavigationRecorder {
    val events = mutableListOf<String>()

    val callbacks = AssistantTaskPageNavigationCallbacks(
        onResumeConversation = { sessionId, onFinished ->
            events += "resume:$sessionId"
            onFinished()
        },
        onResumeSingleFlow = { startListening ->
            events += "single:$startListening"
        },
        onOpenSingleFlow = { initialCommand, startWithVoice ->
            events += "open:$initialCommand:$startWithVoice"
        },
        onOpenSubPage = { page ->
            events += "page:${page.name}"
        }
    )
}
