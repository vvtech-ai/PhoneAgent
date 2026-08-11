package com.vvtech.aiassistant.features.assistant_agent

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AgentStreamCallResultRuntimeHandlerTest {
    @Test
    fun agentStreamHandlerDelegatesOnlyCallResultDiagnostics() {
        val host = sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamHandler.kt")
            .readText(Charsets.UTF_8)
        val actionGraph = sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamActionRuntimeGraph.kt")
            .readText(Charsets.UTF_8)
        val responseGraph = sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamResponseRuntimeGraph.kt")
            .readText(Charsets.UTF_8)
        val runtime = sourceFile(
            "src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamCallResultRuntimeHandler.kt"
        ).readText(Charsets.UTF_8)

        assertTrue(host.contains("AgentStreamCallResultRuntimeHandler("))
        assertTrue(responseGraph.contains("logApplyCallResult = callResultRuntimeHandler::logApplyCallResult"))
        assertFalse(responseGraph.contains("upsertCallResultHistory"))
        assertFalse(responseGraph.contains("upsertBatchCallResultHistory"))
        assertTrue(actionGraph.contains("contextLogger = callResultRuntimeHandler::logAgentContext"))
        assertTrue(host.contains("logAgentContext = callResultRuntimeHandler::logAgentContext"))
        assertTrue(host.lines().size < 500)

        assertFalse(host.contains("AgentStreamCallResultHistoryPolicy"))
        assertFalse(host.contains("private fun upsertCallResultHistory("))
        assertFalse(host.contains("private fun logAgentContext("))
        assertFalse(host.contains("private fun logApplyCallResult("))

        assertFalse(runtime.contains("AgentStreamCallResultHistoryPolicy.localHistoryEntry"))
        assertTrue(runtime.contains("AgentStreamCallResultHistoryPolicy.agentContextLogMessage"))
        assertTrue(runtime.contains("AgentStreamCallResultHistoryPolicy.applyCallResultLogMessage"))
        assertTrue(runtime.contains("\"AGENT_CONTEXT_DIAG\""))
        assertTrue(runtime.contains("\"ReportCallOutcome\""))
        assertTrue(runtime.lines().size <= 100)
        assertFalse(runtime.contains("AssistantViewModel"))
        assertFalse(runtime.contains("AssistantRepository"))
    }

    private companion object {
        fun sourceFile(path: String): File =
            listOf(
                File(path),
                File("android/app/$path")
            ).first { it.exists() }
    }
}
