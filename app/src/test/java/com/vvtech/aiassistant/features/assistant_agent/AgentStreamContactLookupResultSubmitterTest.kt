package com.vvtech.aiassistant.features.assistant_agent

import com.vvtech.aiassistant.core.model.AgentChatResponse
import java.io.File
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class AgentStreamContactLookupResultSubmitterTest {

    @Test
    fun submitContactLookupResultDispatchesResponse() = runBlocking {
        val response = AgentChatResponse(sessionId = "s1", type = "TEXT", text = "ok")
        var captured: CapturedContact? = null
        val consumed = mutableListOf<AgentChatResponse>()
        val submitter = AgentStreamContactLookupResultSubmitter(
            scope = this,
            lookupResultUseCase = AgentStreamContactLookupResultUseCase(
                contactLookupResultProvider = { request ->
                    captured = CapturedContact(
                        request.sessionId,
                        request.pendingToolCallId,
                        request.userId,
                        request.result
                    )
                    response
                },
                deviceContactsLookupResultProvider = { error("device provider should not be called") }
            ),
            responseConsumer = { placeholderIndex, agentResponse ->
                assertEquals(4, placeholderIndex)
                consumed += agentResponse
            },
            failureConsumer = { _, _, _ -> error("failure should not be called") }
        )

        submitter.submitContactLookupResult(
            AgentContactLookupResultSubmitRequest(
                sessionId = "s1",
                pendingToolCallId = "tool-1",
                userId = "u1",
                result = mapOf("found" to true, "displayName" to "小明"),
                placeholderIndex = 4,
                failureMessage = "联系人查询回传失败"
            )
        ).join()

        assertEquals(CapturedContact("s1", "tool-1", "u1", mapOf("found" to true, "displayName" to "小明")), captured)
        assertEquals(listOf(response), consumed)
    }

    @Test
    fun submitDeviceContactsLookupResultIncludesChannel() = runBlocking {
        val response = AgentChatResponse(sessionId = "s1", type = "TEXT", text = "ok")
        var captured: CapturedDeviceContacts? = null
        val submitter = AgentStreamContactLookupResultSubmitter(
            scope = this,
            lookupResultUseCase = AgentStreamContactLookupResultUseCase(
                contactLookupResultProvider = { error("contact provider should not be called") },
                deviceContactsLookupResultProvider = { request ->
                    captured = CapturedDeviceContacts(
                        request.sessionId,
                        request.pendingToolCallId,
                        request.userId,
                        request.results,
                        request.channel
                    )
                    response
                }
            ),
            responseConsumer = { placeholderIndex, agentResponse ->
                assertEquals(6, placeholderIndex)
                assertSame(response, agentResponse)
            },
            failureConsumer = { _, _, _ -> error("failure should not be called") }
        )
        val results = listOf(mapOf("name" to "小明", "status" to "RESOLVED"))

        submitter.submitDeviceContactsLookupResult(
            AgentDeviceContactsLookupResultSubmitRequest(
                sessionId = "s1",
                pendingToolCallId = "tool-2",
                userId = "u1",
                results = results,
                channel = "voice",
                placeholderIndex = 6,
                failureMessage = "联系人查询回传失败"
            )
        ).join()

        assertEquals(CapturedDeviceContacts("s1", "tool-2", "u1", results, "voice"), captured)
    }

    @Test
    fun submitFailureRoutesThroughFailureConsumer() = runBlocking {
        val failure = IllegalStateException("boom")
        var capturedFailure: Throwable? = null
        var capturedMessage: String? = null
        val submitter = AgentStreamContactLookupResultSubmitter(
            scope = this,
            lookupResultUseCase = AgentStreamContactLookupResultUseCase(
                contactLookupResultProvider = { throw failure },
                deviceContactsLookupResultProvider = { error("device provider should not be called") }
            ),
            responseConsumer = { _, _ -> error("response should not be called") },
            failureConsumer = { placeholderIndex, throwable, message ->
                assertEquals(9, placeholderIndex)
                capturedFailure = throwable
                capturedMessage = message
            }
        )

        submitter.submitContactLookupResult(
            AgentContactLookupResultSubmitRequest(
                sessionId = "s1",
                pendingToolCallId = "tool-1",
                userId = "u1",
                result = mapOf("found" to false),
                placeholderIndex = 9,
                failureMessage = "联系人查询回传失败"
            )
        ).join()

        assertSame(failure, capturedFailure)
        assertEquals("联系人查询回传失败", capturedMessage)
    }

    @Test
    fun requestDtoConstructionAndRepositoryWiringLiveInUseCase() {
        val actionGraph = File("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamActionRuntimeGraph.kt")
            .readText(Charsets.UTF_8)
        val submitter =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamContactLookupResultSubmitter.kt")
                .readText(Charsets.UTF_8)
        val useCase =
            File("src/main/java/com/vvtech/aiassistant/features/assistant_agent/AgentStreamContactLookupResultUseCase.kt")
                .readText(Charsets.UTF_8)

        assertTrue(actionGraph.contains("AgentStreamContactLookupResultUseCase(repository)"))
        assertFalse(actionGraph.contains("repository::postContactLookupResult"))
        assertFalse(actionGraph.contains("repository::postDeviceContactsLookupResult"))
        assertFalse(submitter.contains("ContactLookupResultRequest("))
        assertFalse(submitter.contains("DeviceContactsLookupResultRequest("))
        assertTrue(submitter.contains("lookupResultUseCase.submitContactLookupResult(request)"))
        assertTrue(submitter.contains("lookupResultUseCase.submitDeviceContactsLookupResult(request)"))
        assertTrue(useCase.contains("ContactLookupResultRequest("))
        assertTrue(useCase.contains("DeviceContactsLookupResultRequest("))
        assertTrue(useCase.contains("repository::postContactLookupResult"))
        assertTrue(useCase.contains("repository::postDeviceContactsLookupResult"))
        assertTrue(useCase.lines().size <= 300)
    }

    private data class CapturedContact(
        val sessionId: String,
        val pendingToolCallId: String,
        val userId: String,
        val result: Map<String, Any?>
    )

    private data class CapturedDeviceContacts(
        val sessionId: String,
        val pendingToolCallId: String,
        val userId: String,
        val results: List<Map<String, Any?>>,
        val channel: String?
    )
}
