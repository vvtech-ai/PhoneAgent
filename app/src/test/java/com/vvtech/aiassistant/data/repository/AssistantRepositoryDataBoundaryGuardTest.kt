package com.vvtech.aiassistant.data.repository

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantRepositoryDataBoundaryGuardTest {
    @Test
    fun agentStreamRemoteReadLoopStaysOutsideRepository() {
        val repository = sourceFile(
            "src/main/java/com/vvtech/aiassistant/data/repository/AssistantRepository.kt"
        ).readText(Charsets.UTF_8)
        val remoteDataSource = sourceFile(
            "src/main/java/com/vvtech/aiassistant/data/repository/AgentStreamRemoteDataSource.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(repository.contains("AgentStreamRemoteDataSource("))
        assertTrue(repository.contains("return agentStreamRemoteDataSource.stream(request)"))
        assertFalse(repository.contains("streamingApiService.agentChatStream("))
        assertFalse(repository.contains("byteStream()"))
        assertFalse(repository.contains("bufferedReader("))
        assertFalse(repository.contains("while (true)"))
        assertFalse(repository.contains("AgentSseFull"))
        assertFalse(repository.contains("AppFileLogger.logConversation"))
        assertFalse(repository.contains("data.setLength(0)"))

        assertTrue(remoteDataSource.contains("streamingApiService.agentChatStream(request)"))
        assertTrue(remoteDataSource.contains("byteStream().bufferedReader(Charsets.UTF_8)"))
        assertTrue(remoteDataSource.contains("eventParser.parse(ev, payload)"))
        assertTrue(remoteDataSource.contains("if (parsed is AgentStreamEvent.Done) break"))
        assertTrue(remoteDataSource.contains("flowOn(Dispatchers.IO)"))
        assertTrue(
            "AgentStreamRemoteDataSource must stay below 300 lines",
            remoteDataSource.lineSequence().count() < 300
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
