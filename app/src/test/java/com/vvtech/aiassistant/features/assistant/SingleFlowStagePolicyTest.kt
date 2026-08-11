package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.core.model.BatchCallResultPayload
import org.junit.Assert.assertEquals
import org.junit.Test

class SingleFlowStagePolicyTest {
    @Test
    fun terminalBatchCallKeepsResultStageWhileConclusionNarrationIsPlaying() {
        val state = Index9AssistantUiState(
            taskId = "task-1",
            taskStatus = "COMPLETED",
            processingTurn = false,
            voiceActive = true,
            apiTtsPlaying = true,
            liveAssistantTranscript = "both contacts confirmed",
            agentCallResult = null,
            clarificationSteps = listOf(
                ClarificationStep(
                    role = VoiceRole.Assistant,
                    text = "meeting invitation completed",
                    status = "completed",
                    batchCallResult = BatchCallResultPayload(
                        status = "COMPLETED",
                        headline = "invitation completed",
                        items = emptyList()
                    )
                )
            )
        )

        assertEquals(4, sfRealRestaurantStage(state))
    }

    @Test
    fun terminalBatchCallWithNewUserTurnStillShowsDialogueStage() {
        val state = Index9AssistantUiState(
            taskId = "task-1",
            taskStatus = "COMPLETED",
            processingTurn = true,
            liveUserTranscript = "start another task",
            agentCallResult = null,
            clarificationSteps = listOf(
                ClarificationStep(
                    role = VoiceRole.Assistant,
                    text = "meeting invitation completed",
                    status = "completed",
                    batchCallResult = BatchCallResultPayload(
                        status = "COMPLETED",
                        headline = "invitation completed",
                        items = emptyList()
                    )
                )
            )
        )

        assertEquals(1, sfRealRestaurantStage(state))
    }

    @Test
    fun failedCallContinuationShowsDialogueStageInsteadOfStaleResultStage() {
        val state = Index9AssistantUiState(
            taskId = "task-1",
            taskStatus = "FAILED",
            processingTurn = true,
            agentCallResult = null,
            clarificationSteps = listOf(
                ClarificationStep(
                    role = VoiceRole.User,
                    text = "continue",
                    status = "sent"
                )
            ),
            callPageData = CallPageData(
                name = "merchant",
                sub = "phone",
                status = "call ended",
                transcript = listOf(
                    TranscriptLine(TranscriptRole.Remote, "not available")
                )
            )
        )

        assertEquals(1, sfRealRestaurantStage(state))
    }
}
