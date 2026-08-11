package com.vvtech.aiassistant.data.repository

import com.vvtech.aiassistant.core.model.AgentStreamEvent
import org.junit.Assert.assertNull
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantRepositoryAgentEventMappingTest {

    private val parser = AgentStreamSseEventParser()

    @Test
    fun permissionRequestPayloadCanBeParsedFromNestedClientData() {
        val payload = agentPermissionRequestFromClientData(
            mapOf(
                "permissionRequest" to mapOf(
                    "permissionKey" to "contacts",
                    "androidPermission" to "android.permission.READ_CONTACTS",
                    "reason" to "Need contacts to place the call",
                    "statusBeforeRequest" to "DENIED"
                )
            )
        )

        assertEquals("contacts", payload.permissionKey)
        assertEquals("android.permission.READ_CONTACTS", payload.androidPermission)
        assertEquals("Need contacts to place the call", payload.reason)
        assertEquals("DENIED", payload.statusBeforeRequest)
    }

    @Test
    fun documentImportPayloadNormalizesListsAndNumericMaxBytes() {
        val payload = agentDocumentImportRequestFromClientData(
            mapOf(
                "documentImportRequest" to mapOf(
                    "title" to "Upload a document",
                    "reason" to "Read the meeting notice",
                    "acceptedTypes" to listOf("markdown", "text"),
                    "acceptedMimeTypes" to "text/markdown,text/plain",
                    "maxBytes" to 5_242_880.0
                )
            )
        )

        assertEquals("Upload a document", payload.title)
        assertEquals("Read the meeting notice", payload.reason)
        assertEquals(listOf("markdown", "text"), payload.acceptedTypes)
        assertEquals(listOf("text/markdown", "text/plain"), payload.acceptedMimeTypes)
        assertEquals(5_242_880L, payload.maxBytes)
    }

    @Test
    fun documentImportPayloadCanBeParsedFromFlattenedClientData() {
        val payload = agentDocumentImportRequestFromClientData(
            mapOf(
                "title" to "Choose file",
                "acceptedTypes" to listOf("markdown"),
                "maxBytes" to "2048"
            )
        )

        assertEquals("Choose file", payload.title)
        assertEquals(listOf("markdown"), payload.acceptedTypes)
        assertEquals(2048L, payload.maxBytes)
    }

    @Test
    fun deviceContactsLookupClientEventMapsToSignalPayload() {
        val event = parser.parse(
            "agent_lookup_device_contacts_by_names",
            """
            {
              "sessionId": "session-1",
              "displayMessage": "select contacts",
              "data": {
                "pendingToolCallId": "tool-1",
                "names": ["\u5c0f\u660e", "\u5f20\u4e09"],
                "reason": "call"
              }
            }
            """.trimIndent()
        )

        val signal = event as AgentStreamEvent.Signal
        assertEquals("LOOKUP_DEVICE_CONTACTS_BY_NAMES_REQUEST", signal.payload.type)
        assertEquals("tool-1", signal.payload.pendingToolCallId)
        assertEquals(listOf("\u5c0f\u660e", "\u5f20\u4e09"), signal.payload.lookupDeviceContactsByNames?.names)
        assertEquals("call", signal.payload.lookupDeviceContactsByNames?.reason)
    }

    @Test
    fun callReadyClientEventMapsToMakeCallRequest() {
        val event = parser.parse(
            "call_ready",
            """
            {
              "sessionId": "session-2",
              "displayMessage": "ready",
              "data": {
                "pendingToolCallId": "tool-call",
                "phoneNumber": "13800138000",
                "scene": "RESTAURANT_BOOKING",
                "targetName": "\u5317\u6d77\u6e14\u6751",
                "primaryGoal": "reserve room",
                "summaryLines": ["line1", "line2"]
              }
            }
            """.trimIndent()
        )

        val signal = event as AgentStreamEvent.Signal
        assertEquals("MAKE_CALL_REQUEST", signal.payload.type)
        assertEquals("tool-call", signal.payload.pendingToolCallId)
        assertEquals("13800138000", signal.payload.callSpec?.phoneNumber)
        assertEquals("RESTAURANT_BOOKING", signal.payload.callSpec?.scene)
        assertEquals("\u5317\u6d77\u6e14\u6751", signal.payload.callSpec?.targetName)
        assertEquals(listOf("line1", "line2"), signal.payload.callSpec?.summaryLines)
    }

    @Test
    fun taskCompletedClientEventMapsCallResultFinal() {
        val event = parser.parse(
            "task_completed",
            """
            {
              "sessionId": "session-3",
              "displayMessage": "done",
              "data": {
                "callResult": {
                  "status": "SUCCESS",
                  "headline": "reserved",
                  "detail": "room booked",
                  "metadata": {"agentOutcome": "SUCCESS"}
                }
              }
            }
            """.trimIndent()
        )

        val final = event as AgentStreamEvent.Final
        assertEquals("CALL_RESULT", final.payload.type)
        assertEquals("SUCCESS", final.payload.callResult?.status)
        assertEquals("reserved", final.payload.callResult?.headline)
        assertEquals("SUCCESS", final.payload.callResult?.metadata?.get("agentOutcome"))
    }

    @Test
    fun taskFailedClientEventKeepsAssistantReplyWithoutAppendingCallDiagnostics() {
        val assistantReply = "海底捞电话没打通，要不要换一家再打？或者等会儿再试一次？"
        val internalDetail = "发起 INVITE 后没有等到最终响应。APP侧固定外呼号码已生效：尾号 0986"
        val event = parser.parse(
            "task_failed",
            """
            {
              "sessionId": "session-failed",
              "displayMessage": "$assistantReply",
              "data": {
                "callResult": {
                  "status": "FAILED",
                  "headline": "电话未接通",
                  "detail": "$internalDetail"
                }
              }
            }
            """.trimIndent()
        )

        val final = event as AgentStreamEvent.Final
        assertEquals("CALL_RESULT", final.payload.type)
        assertEquals(assistantReply, final.payload.text)
        assertEquals("电话未接通", final.payload.callResult?.headline)
        assertEquals(internalDetail, final.payload.callResult?.detail)
    }

    @Test
    fun taskFailedClientEventWithoutResultMapsToError() {
        val event = parser.parse(
            "task_failed",
            """
            {
              "sessionId": "session-4",
              "displayMessage": "backend failed",
              "data": {}
            }
            """.trimIndent()
        )

        val error = event as AgentStreamEvent.Err
        assertEquals("backend failed", error.message)
    }

    @Test
    fun unknownAndMalformedAgentEventsAreDropped() {
        assertNull(parser.parse("unknown_event", """{"data":{}}"""))
        assertNull(parser.parse("call_ready", "{"))
    }
}
