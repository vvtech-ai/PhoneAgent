package com.vvtech.aiassistant.features.assistant_session

import com.vvtech.aiassistant.features.assistant.AssistantStage
import com.vvtech.aiassistant.features.assistant.ClarificationStep
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.SelectionSheetData
import com.vvtech.aiassistant.features.assistant.SelectionSheetOption
import com.vvtech.aiassistant.features.assistant.SummaryData
import com.vvtech.aiassistant.features.assistant.VoiceRole
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantSessionApplyStateReducerTest {
    @Test
    fun textApplyStateUsesActionableSummaryAsRecognizedTask() {
        val state = Index9AssistantUiState(
            liveUserTranscript = "speaking",
            liveAssistantTranscript = "answering",
            loading = true,
            processingTurn = true,
            error = "old"
        )

        val updated = AssistantSessionApplyStateReducer.reduceTextApplyState(
            state = state,
            context = textContext(
                summary = summary(),
                confirmLabel = "Go",
                backendSteps = listOf(step(VoiceRole.User, "book a room"))
            )
        )

        assertEquals("task-1", updated.taskId)
        assertEquals("FOOD_ORDERING", updated.sceneType)
        assertEquals("RUNNING", updated.taskStatus)
        assertEquals(AssistantStage.Recognized, updated.stage)
        assertEquals("ready", updated.status)
        assertEquals(listOf(step(VoiceRole.User, "book a room")), updated.clarificationSteps)
        assertEquals(summary(), updated.summary)
        assertEquals("Go", updated.confirmLabel)
        assertNull(updated.liveUserTranscript)
        assertNull(updated.liveAssistantTranscript)
        assertNull(updated.detailSupplement)
        assertFalse(updated.loading)
        assertFalse(updated.processingTurn)
        assertNull(updated.error)
    }

    @Test
    fun textApplyStateUsesSelectionSheetBeforeBackendStepStatus() {
        val sheet = selectionSheet()

        val updated = AssistantSessionApplyStateReducer.reduceTextApplyState(
            state = Index9AssistantUiState(),
            context = textContext(
                backendSteps = listOf(step(VoiceRole.Assistant, "choose one")),
                selectionSheet = sheet,
                selectionStatus = "choose restaurant"
            )
        )

        assertEquals(AssistantStage.Clarifying, updated.stage)
        assertEquals("choose restaurant", updated.status)
        assertSame(sheet, updated.selectionSheet)
        assertNull(updated.summary)
    }

    @Test
    fun voiceApplyStateClearsRealtimeFieldsWhenNotPreserved() {
        val updated = AssistantSessionApplyStateReducer.reduceVoiceApplyState(
            state = Index9AssistantUiState(
                liveUserTranscript = "live user",
                liveAssistantTranscript = "live assistant",
                listening = true,
                processingTurn = true,
                error = "old"
            ),
            context = voiceContext(
                displayedSteps = listOf(step(VoiceRole.Assistant, "continue"))
            )
        )

        assertEquals(AssistantStage.Clarifying, updated.stage)
        assertEquals("continuing", updated.status)
        assertEquals(listOf(step(VoiceRole.Assistant, "continue")), updated.clarificationSteps)
        assertNull(updated.liveUserTranscript)
        assertNull(updated.liveAssistantTranscript)
        assertFalse(updated.listening)
        assertFalse(updated.processingTurn)
        assertNull(updated.error)
    }

    @Test
    fun voiceApplyStatePreservesRealtimeUiWhenRequested() {
        val updated = AssistantSessionApplyStateReducer.reduceVoiceApplyState(
            state = Index9AssistantUiState(
                status = "still listening",
                liveUserTranscript = "live user",
                liveAssistantTranscript = "live assistant",
                listening = true,
                processingTurn = true
            ),
            context = voiceContext(
                preserveRealtimeUi = true,
                displayedSteps = emptyList()
            )
        )

        assertEquals(AssistantStage.Clarifying, updated.stage)
        assertEquals("still listening", updated.status)
        assertEquals("live user", updated.liveUserTranscript)
        assertEquals("live assistant", updated.liveAssistantTranscript)
        assertTrue(updated.listening)
        assertTrue(updated.processingTurn)
    }

    @Test
    fun voiceApplyStateCanPreloadDeferredAssistantPrompt() {
        val updated = AssistantSessionApplyStateReducer.reduceVoiceApplyState(
            state = Index9AssistantUiState(),
            context = voiceContext(
                shouldDeferLatestAssistantPromptForVoice = true,
                newestBackendAssistantPrompt = "confirm details"
            )
        )

        assertEquals("confirm details", updated.liveAssistantTranscript)
    }

    @Test
    fun sessionMapperDelegatesApplyStateMaintenance() {
        val mapper = sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_session/SessionMapper.kt")
            .readText(Charsets.UTF_8)
        val textApplyHandler = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_session/AssistantSessionTextApplyHandler.kt"
        ).readText(Charsets.UTF_8)
        val voiceApplyHandler = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_session/AssistantSessionVoiceApplyHandler.kt"
        ).readText(Charsets.UTF_8)
        val reducer = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_session/AssistantSessionApplyStateReducer.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(textApplyHandler.contains("AssistantSessionApplyStateReducer.reduceTextApplyState"))
        assertTrue(voiceApplyHandler.contains("AssistantSessionApplyStateReducer.reduceVoiceApplyState"))
        assertTrue(textApplyHandler.contains("AssistantSessionApplyStateReducer.TextContext"))
        assertTrue(voiceApplyHandler.contains("AssistantSessionApplyStateReducer.VoiceContext"))
        assertTrue(textApplyHandler.contains("AssistantSessionApplyStateReducer.SessionIdentity"))
        assertTrue(voiceApplyHandler.contains("AssistantSessionApplyStateReducer.SessionIdentity"))
        assertTrue(textApplyHandler.contains("AssistantSessionApplyStateReducer.ApplyContent"))
        assertTrue(voiceApplyHandler.contains("AssistantSessionApplyStateReducer.ApplyContent"))
        assertTrue(textApplyHandler.contains("AssistantSessionApplyStateReducer.ApplyStatusText"))
        assertTrue(voiceApplyHandler.contains("AssistantSessionApplyStateReducer.ApplyStatusText"))
        assertFalse(mapper.contains("AssistantSessionApplyStateReducer.reduceTextApplyState"))
        assertFalse(mapper.contains("AssistantSessionApplyStateReducer.reduceVoiceApplyState"))
        assertFalse(mapper.contains("val hasVisibleConversation"))
        assertFalse(mapper.contains("shouldDeferLatestAssistantPromptForVoice -> newestBackendAssistantPrompt"))

        assertTrue(reducer.contains("fun reduceTextApplyState"))
        assertTrue(reducer.contains("fun reduceVoiceApplyState"))
        assertTrue(reducer.contains("data class TextContext"))
        assertTrue(reducer.contains("data class VoiceContext"))
        assertTrue(reducer.contains("data class VoiceRealtimeOptions"))
    }

    private fun textContext(
        backendSteps: List<ClarificationStep> = emptyList(),
        selectionSheet: SelectionSheetData? = null,
        summary: SummaryData? = null,
        confirmLabel: String = "Confirm",
        selectionStatus: String? = null
    ): AssistantSessionApplyStateReducer.TextContext {
        return AssistantSessionApplyStateReducer.TextContext(
            identity = identity(),
            content = AssistantSessionApplyStateReducer.ApplyContent(
                steps = backendSteps,
                selectionSheet = selectionSheet,
                summary = summary,
                confirmLabel = confirmLabel
            ),
            statusText = statusText(selectionStatus)
        )
    }

    private fun voiceContext(
        displayedSteps: List<ClarificationStep> = emptyList(),
        selectionSheet: SelectionSheetData? = null,
        summary: SummaryData? = null,
        confirmLabel: String = "Confirm",
        selectionStatus: String? = null,
        preserveRealtimeUi: Boolean = false,
        keepRealtimeDialog: Boolean = false,
        shouldDeferLatestAssistantPromptForVoice: Boolean = false,
        newestBackendAssistantPrompt: String? = null
    ): AssistantSessionApplyStateReducer.VoiceContext {
        return AssistantSessionApplyStateReducer.VoiceContext(
            identity = identity(),
            content = AssistantSessionApplyStateReducer.ApplyContent(
                steps = displayedSteps,
                selectionSheet = selectionSheet,
                summary = summary,
                confirmLabel = confirmLabel
            ),
            statusText = statusText(selectionStatus),
            realtime = AssistantSessionApplyStateReducer.VoiceRealtimeOptions(
                preserveRealtimeUi = preserveRealtimeUi,
                keepRealtimeDialog = keepRealtimeDialog,
                shouldDeferLatestAssistantPromptForVoice = shouldDeferLatestAssistantPromptForVoice,
                newestBackendAssistantPrompt = newestBackendAssistantPrompt
            )
        )
    }

    private fun identity(): AssistantSessionApplyStateReducer.SessionIdentity {
        return AssistantSessionApplyStateReducer.SessionIdentity(
            taskId = "task-1",
            sceneType = "FOOD_ORDERING",
            taskStatus = "RUNNING"
        )
    }

    private fun statusText(selectionStatus: String?): AssistantSessionApplyStateReducer.ApplyStatusText {
        return AssistantSessionApplyStateReducer.ApplyStatusText(
            taskReadyStatus = "ready",
            selectionStatus = selectionStatus,
            continuingStatus = "continuing",
            idleStatus = "idle"
        )
    }

    private fun step(role: VoiceRole, text: String): ClarificationStep {
        return ClarificationStep(role = role, text = text, status = "")
    }

    private fun summary(): SummaryData {
        return SummaryData(
            task = "Task",
            targetLabel = "Target",
            target = "Restaurant",
            timeLabel = "Time",
            time = "Tonight",
            extraLabel = "Details",
            extra = "Private room"
        )
    }

    private fun selectionSheet(): SelectionSheetData {
        return SelectionSheetData(
            title = "Choose",
            subtitle = "Pick one",
            targetLabel = "restaurant",
            options = listOf(
                SelectionSheetOption(
                    itemId = "item-1",
                    title = "North Sea",
                    phone = "10086",
                    meta = "Seafood",
                    actionId = "action-1",
                    actionLabel = "Call"
                )
            )
        )
    }

    private companion object {
        fun sourceFile(path: String): File {
            return listOf(
                File(path),
                File("android/app/$path")
            ).first { it.exists() }
        }
    }
}
