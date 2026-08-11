package com.vvtech.aiassistant.features.assistant_home

import com.vvtech.aiassistant.features.assistant.ClarificationStep
import com.vvtech.aiassistant.features.assistant.PartialToolCall
import com.vvtech.aiassistant.features.assistant.VoiceRole
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantHomeProgressStagePolicyTest {
    @Test
    fun resolvesProgressStageByPriority() {
        assertEquals(
            1,
            resolveAssistantHomeProgressStage(
                taskStatus = "",
                taskStarted = false,
                voiceRecording = false,
                processingTurn = false,
                clarificationSteps = emptyList()
            )
        )
        assertEquals(
            1,
            resolveAssistantHomeProgressStage(
                taskStatus = "",
                taskStarted = true,
                voiceRecording = false,
                processingTurn = false,
                clarificationSteps = emptyList()
            )
        )
        assertEquals(
            2,
            resolveAssistantHomeProgressStage(
                taskStatus = "",
                taskStarted = true,
                voiceRecording = false,
                processingTurn = false,
                clarificationSteps = listOf(assistantStep(text = "识别当前任务为餐厅预订"))
            )
        )
        assertEquals(
            3,
            resolveAssistantHomeProgressStage(
                taskStatus = "",
                taskStarted = true,
                voiceRecording = false,
                processingTurn = false,
                clarificationSteps = listOf(
                    assistantStep(
                        text = "准备拨打",
                        partialToolCalls = listOf(PartialToolCall("tool-1", "makeCall", "{}"))
                    )
                )
            )
        )
        assertEquals(
            4,
            resolveAssistantHomeProgressStage(
                taskStatus = "SUCCESS",
                taskStarted = true,
                voiceRecording = false,
                processingTurn = false,
                clarificationSteps = listOf(
                    assistantStep(
                        text = "正在拨打",
                        callStatusEvents = listOf("通话执行中")
                    )
                )
            )
        )
    }

    @Test
    fun homeProgressStagePolicyStaysOutOfLegacyPage() {
        val pageFile = sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/FinalHomePage.kt")
        val legacyFile = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_conversation/ui/page/AssistantConversationLegacyHomePage.kt"
        )
        val contractFile = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_home/AssistantHomePageContract.kt"
        )
        val policyFile = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_home/AssistantHomeProgressStagePolicy.kt"
        )
        val page = pageFile.readText(Charsets.UTF_8)
        val legacy = legacyFile.readText(Charsets.UTF_8)
        val contract = contractFile.readText(Charsets.UTF_8)
        val policy = policyFile.readText(Charsets.UTF_8)

        assertTrue("FinalHomePage should stay below the page guard threshold.", pageFile.readLines(Charsets.UTF_8).size < 500)
        assertTrue("Legacy home wrapper should stay a thin compatibility bridge.", legacyFile.readLines(Charsets.UTF_8).size <= 60)
        assertTrue("Home page contract must stay below the new-file guard threshold.", contractFile.readLines(Charsets.UTF_8).size <= 140)
        assertTrue("Home progress policy must stay below the new-file guard threshold.", policyFile.readLines(Charsets.UTF_8).size <= 120)
        assertTrue(
            "FinalHomePage should delegate progress stage resolution to assistant_home policy.",
            page.contains("import com.vvtech.aiassistant.features.assistant_home.resolveAssistantHomeProgressStage") &&
                page.contains("val activeProgressStage = resolveAssistantHomeProgressStage(")
        )
        assertTrue(
            "Home page should consume grouped state/callback contracts.",
            page.contains("composerState: AssistantHomeComposerState") &&
                page.contains("taskState: AssistantHomeTaskState") &&
                page.contains("callbacks: AssistantHomePageCallbacks") &&
                contract.contains("internal data class AssistantHomeComposerState(") &&
                contract.contains("internal data class AssistantHomePageCallbacks(")
        )
        assertTrue(
            "Legacy conversation home wrapper should remain a thin bridge to the grouped Home page contract.",
            legacy.contains("composerState: AssistantHomeComposerState") &&
                legacy.contains("FinalHomeAssistantPage(") &&
                legacy.contains("callbacks = callbacks")
        )
        forbiddenPageTokens.forEach { token ->
            assertFalse("Home progress policy token must not return to FinalHomePage: $token", page.contains(token))
        }
        forbiddenLongSignatureTokens.forEach { token ->
            assertFalse("Long Home page parameter token must not return to FinalHomePage: $token", page.contains(token))
            assertFalse("Long Home page parameter token must not return to legacy wrapper: $token", legacy.contains(token))
        }
        assertTrue(
            "Home progress policy should keep the stage priority contract.",
            policy.contains("hasResult -> 4") &&
                policy.contains("hasCallExecution -> 3") &&
                policy.contains("hasRequirementConfirmation -> 2")
        )
        bannedRuntimeDependencies.forEach { dependency ->
            assertFalse(
                "Home progress stage policy must not depend on runtime/data dependency: $dependency",
                policy.contains(dependency)
            )
        }
        bannedContractRuntimeDependencies.forEach { dependency ->
            assertFalse(
                "Home page contract must not depend on runtime dependency: $dependency",
                contract.contains(dependency)
            )
        }
    }

    private companion object {
        val forbiddenPageTokens = listOf(
            "private fun resolveFinalHomeProgressStage",
            "val progressText =",
            "hasRunningBatchCallResult",
            "hasFinalBatchCallResult",
            "hasRequirementConfirmation",
            "hasCallExecution",
            "hasResult"
        )

        val forbiddenLongSignatureTokens = listOf(
            "assistantFocused: Boolean",
            "composerOpen: Boolean",
            "agentQuestions:",
            "agentOptions:",
            "onAgentAnswerSubmit:",
            "homeNotificationVisible:"
        )

        val bannedRuntimeDependencies = listOf(
            "Repository",
            "AssistantContainer",
            "AppContainer",
            "VoiceDuplexCoordinator",
            "VoiceRuntimeHandler",
            "AudioTrack",
            "MediaPlayer",
            "Asr",
            "Tts",
            "SIP",
            "AgentStream",
            "androidx.compose"
        )

        val bannedContractRuntimeDependencies = bannedRuntimeDependencies - listOf("Asr", "Tts")

        fun assistantStep(
            text: String,
            callStatusEvents: List<String> = emptyList(),
            partialToolCalls: List<PartialToolCall> = emptyList()
        ): ClarificationStep {
            return ClarificationStep(
                role = VoiceRole.Assistant,
                text = text,
                status = "",
                callStatusEvents = callStatusEvents,
                partialToolCalls = partialToolCalls
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
