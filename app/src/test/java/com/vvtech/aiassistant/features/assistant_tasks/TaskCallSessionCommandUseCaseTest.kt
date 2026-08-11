package com.vvtech.aiassistant.features.assistant_tasks

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TaskCallSessionCommandUseCaseTest {
    @Test
    fun handoffRequestPlansKeepCommandReasonsAndIds() {
        val requestHuman = taskCallSessionHandoffRequestPlan(
            command = TaskCallSessionHandoffCommand.RequestHumanTakeover,
            userId = "user-1",
            taskId = "task-1",
            callId = "call-1"
        )
        val releaseToAi = taskCallSessionHandoffRequestPlan(
            command = TaskCallSessionHandoffCommand.ReleaseToAi,
            userId = "user-1",
            taskId = "task-2",
            callId = "call-2"
        )
        val hangUp = taskCallSessionHandoffRequestPlan(
            command = TaskCallSessionHandoffCommand.HangUp,
            userId = "user-1",
            taskId = "task-3",
            callId = "call-3"
        )

        assertEquals(TaskCallSessionHandoffCommand.RequestHumanTakeover, requestHuman.command)
        assertEquals("user-1", requestHuman.request.userId)
        assertEquals("task-1", requestHuman.request.taskId)
        assertEquals("call-1", requestHuman.request.callId)
        assertEquals("用户在 App 端请求人工接管", requestHuman.request.reason)

        assertEquals("task-2", releaseToAi.request.taskId)
        assertEquals("call-2", releaseToAi.request.callId)
        assertEquals("用户在 App 端请求切回 AI 代打", releaseToAi.request.reason)

        assertEquals("task-3", hangUp.request.taskId)
        assertEquals("call-3", hangUp.request.callId)
        assertEquals("用户在 App 端挂断通话", hangUp.request.reason)
    }

    @Test
    fun statusRequestPlanKeepsStatusRefreshIds() {
        val plan = taskCallSessionStatusRequestPlan(
            userId = "user-1",
            taskId = "task-1",
            callId = "call-1"
        )

        assertEquals("user-1", plan.request.userId)
        assertEquals("task-1", plan.request.taskId)
        assertEquals("call-1", plan.request.callId)
    }

    @Test
    fun callActionHandlerDelegatesCommandsToTaskUseCase() {
        val handler =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/viewmodel/CallActionHandler.kt")
                .readText(Charsets.UTF_8)
        val userCommandController =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_tasks/TaskCallSessionUserCommandController.kt")
                .readText(Charsets.UTF_8)
        val useCase =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_tasks/TaskCallSessionCommandUseCase.kt")
                .readText(Charsets.UTF_8)

        assertTrue(handler.contains("TaskCallSessionCommandUseCase(repository)"))
        assertTrue(handler.contains("TaskCallSessionUserCommandController("))
        assertFalse(handler.contains("callSessionCommandUseCase.requestHumanTakeover("))
        assertFalse(handler.contains("callSessionCommandUseCase.releaseToAi("))
        assertFalse(handler.contains("callSessionCommandUseCase.hangUp("))
        assertTrue(userCommandController.contains("deps.commandUseCase.requestHumanTakeover("))
        assertTrue(userCommandController.contains("deps.commandUseCase.releaseToAi("))
        assertTrue(userCommandController.contains("deps.commandUseCase.hangUp("))
        assertFalse(handler.contains("CallHandoffRequest("))
        assertFalse(handler.contains("CallSessionStatusRequest("))
        assertFalse(handler.contains("repository.requestCallHandoff("))
        assertFalse(handler.contains("repository.releaseCallHandoff("))
        assertFalse(handler.contains("repository.hangUpCall("))
        assertFalse(handler.contains("repository.getCallSessionStatus("))

        assertTrue(useCase.contains("CallHandoffRequest("))
        assertTrue(useCase.contains("CallSessionStatusRequest("))
        assertTrue(useCase.contains("repository.requestCallHandoff("))
        assertTrue(useCase.contains("repository.releaseCallHandoff("))
        assertTrue(useCase.contains("repository.hangUpCall("))
        assertTrue(useCase.contains("suspend fun refreshStatus("))
        assertTrue(useCase.contains("repository.getCallSessionStatus("))
    }

    private companion object {
        fun sourceFile(relativePath: String): File {
            return generateSequence(File(".").absoluteFile) { it.parentFile }
                .map { File(it, relativePath) }
                .first { it.exists() }
        }
    }
}
