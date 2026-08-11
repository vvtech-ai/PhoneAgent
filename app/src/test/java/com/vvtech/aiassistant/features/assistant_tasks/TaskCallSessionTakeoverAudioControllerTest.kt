package com.vvtech.aiassistant.features.assistant_tasks

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TaskCallSessionTakeoverAudioControllerTest {
    @Test
    fun reconnectDelayUsesDefaultForMicrophoneErrorsAndFastDelayOtherwise() {
        assertEquals(
            900L,
            taskCallSessionTakeoverReconnectDelayMillis(
                message = "麦克风权限异常",
                defaultDelayMillis = 900L
            )
        )
        assertEquals(
            450L,
            taskCallSessionTakeoverReconnectDelayMillis(
                message = "socket closed",
                defaultDelayMillis = 900L
            )
        )
    }

    @Test
    fun callActionHandlerDelegatesTakeoverAudioStateMachineToController() {
        val handler =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/viewmodel/CallActionHandler.kt")
                .readText(Charsets.UTF_8)
        val controller =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_tasks/TaskCallSessionTakeoverAudioController.kt")
                .readText(Charsets.UTF_8)
        val userCommandController =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_tasks/TaskCallSessionUserCommandController.kt")
                .readText(Charsets.UTF_8)

        assertTrue(handler.contains("TaskCallSessionTakeoverAudioController("))
        assertTrue(handler.contains("prepareHumanTakeoverRequest = takeoverAudioController::prepareHumanTakeoverRequest"))
        assertTrue(userCommandController.contains("deps.prepareHumanTakeoverRequest()"))
        assertTrue(handler.contains("takeoverAudioController.setCaptureEnabled(enabled)"))
        assertTrue(handler.contains("takeoverAudioController.setSpeakerphoneEnabled(enabled)"))
        assertTrue(handler.contains("takeoverAudioController.ensure(taskId, callId)"))
        assertTrue(handler.contains("takeoverAudioController.stop()"))
        assertTrue(handler.contains("takeoverAudioController.handleEvent(event)"))
        assertTrue(handler.contains("takeoverAudioController.scheduleReconnect(delayMillis)"))
        assertFalse(handler.contains("when (event)"))
        assertFalse(handler.contains("is TakeoverAudioSocketClient.Event.Error"))
        assertFalse(handler.contains("人工接管音频重连中"))
        assertFalse(handler.contains("takeoverAudioSocketClient.start("))
        assertFalse(handler.contains("takeoverAudioSocketClient.release()"))

        assertTrue(controller.contains("TakeoverAudioSocketClient.Event"))
        assertTrue(controller.contains("fun handleEvent("))
        assertTrue(controller.contains("fun scheduleReconnect("))
        assertTrue(controller.contains("人工接管音频重连中"))
        assertTrue(controller.contains("deps.socketClient.start("))
        assertTrue(controller.contains("deps.socketClient.release()"))
    }

    private companion object {
        fun sourceFile(relativePath: String): File {
            return generateSequence(File(".").absoluteFile) { it.parentFile }
                .map { File(it, relativePath) }
                .first { it.exists() }
        }
    }
}
