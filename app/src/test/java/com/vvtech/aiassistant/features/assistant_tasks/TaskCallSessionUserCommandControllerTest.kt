package com.vvtech.aiassistant.features.assistant_tasks

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TaskCallSessionUserCommandControllerTest {
    @Test
    fun callActionHandlerDelegatesUserCommandFlowToTaskController() {
        val handler =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/viewmodel/CallActionHandler.kt")
                .readText(Charsets.UTF_8)
        val controller =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_tasks/TaskCallSessionUserCommandController.kt")
                .readText(Charsets.UTF_8)
        val normalizedController = controller.replace("\r\n", "\n")

        assertTrue(handler.contains("TaskCallSessionUserCommandController("))
        assertTrue(handler.contains("userCommandController.requestHumanTakeover()"))
        assertTrue(handler.contains("userCommandController.releaseToAi()"))
        assertTrue(handler.contains("userCommandController.hangUpCall("))

        assertFalse(handler.contains("callSessionCommandUseCase.requestHumanTakeover("))
        assertFalse(handler.contains("callSessionCommandUseCase.releaseToAi("))
        assertFalse(handler.contains("callSessionCommandUseCase.hangUp("))
        assertFalse(handler.contains("正在请求人工接管..."))
        assertFalse(handler.contains("正在切回 AI 代打..."))
        assertFalse(handler.contains("正在挂断通话..."))
        assertFalse(handler.contains("人工接管请求失败，请稍后再试"))
        assertFalse(handler.contains("切回 AI 失败，请稍后再试"))
        assertFalse(handler.contains("挂断失败，请稍后再试"))

        assertTrue(controller.contains("deps.stopAssistantSpeech()"))
        assertTrue(controller.contains("deps.stopVoiceInteraction()"))
        assertTrue(controller.contains("deps.prepareHumanTakeoverRequest()"))
        assertTrue(controller.contains("deps.commandUseCase.requestHumanTakeover("))
        assertTrue(controller.contains("deps.commandUseCase.releaseToAi("))
        assertTrue(controller.contains("deps.commandUseCase.hangUp("))
        assertTrue(controller.contains("val userIdProvider: () -> String"))
        assertTrue(controller.contains("userId = deps.userIdProvider()"))
        assertFalse(controller.contains("val userId: String"))
        assertTrue(handler.contains("userIdProvider = { DefaultUserId }"))
        assertFalse(handler.contains("userId = DefaultUserId"))
        assertTrue(controller.contains("deps.stopTakeoverAudioSocket()"))
        assertTrue(controller.contains("deps.stopCallSessionPolling()"))
        assertTrue(
            normalizedController.contains(
                "deps.stopCallSessionPolling()\n" +
                    "                deps.applyCallSessionStatus(response, true)\n" +
                    "                deps.dismissAiCallPage()"
            )
        )
        assertFalse(controller.contains("clearHomeProjection"))
        assertFalse(controller.contains("returnToAssistantHomeFromCallPage"))
        assertFalse(controller.contains("taskCallSessionManualHangupHistoryPlan("))
        assertFalse(controller.contains("upsertLocalCallHistory"))
        assertTrue(controller.contains("deps.dismissAiCallPage()"))
    }

    private companion object {
        fun sourceFile(relativePath: String): File {
            return generateSequence(File(".").absoluteFile) { it.parentFile }
                .map { File(it, relativePath) }
                .first { it.exists() }
        }
    }
}
