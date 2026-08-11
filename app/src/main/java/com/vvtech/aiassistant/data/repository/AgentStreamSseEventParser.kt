package com.vvtech.aiassistant.data.repository

import com.google.gson.Gson
import com.google.gson.JsonObject
import com.vvtech.aiassistant.core.model.AgentChatResponse
import com.vvtech.aiassistant.core.model.AgentStreamEvent
import com.vvtech.aiassistant.core.model.AskQuestionsPayload
import com.vvtech.aiassistant.core.model.BatchCallResultPayload
import com.vvtech.aiassistant.core.model.CallResultPayload
import com.vvtech.aiassistant.core.model.LookupDeviceContactsByNamesPayload
import com.vvtech.aiassistant.core.model.OptionsPayload
import com.vvtech.aiassistant.core.model.ToolCardInfo
import com.vvtech.aiassistant.data.remote.timeline.ConversationTimelineEventDto
import com.vvtech.aiassistant.data.remote.timeline.ConversationTimelineWireMapper

internal class AgentStreamSseEventParser(
    private val gson: Gson = Gson(),
    private val terminalCallResultLogger: AgentStreamTerminalCallResultLogger =
        ::logAgentStreamTerminalCallResultEvent
) {
    fun isClientLogEvent(event: String): Boolean {
        return isAgentClientEvent(event) || event == "heartbeat"
    }

    fun isConversationEvent(event: String): Boolean {
        return isAgentClientEvent(event) || isRawAgentEvent(event)
    }

    fun parse(event: String, dataJson: String): AgentStreamEvent? {
        if (event == "heartbeat") return AgentStreamEvent.Heartbeat
        return runCatching {
            if (event == "timeline_committed") {
                return parseTimelineCommitted(dataJson)
            }
            val map = gson.fromJson(dataJson, Map::class.java)
                ?.let { @Suppress("UNCHECKED_CAST") (it as Map<String, Any?>) }
                ?: emptyMap()
            parseClientAgentEvent(event, map) ?: parseRawAgentEvent(event, map, dataJson)
        }.getOrNull()
    }

    private fun parseTimelineCommitted(dataJson: String): AgentStreamEvent.TimelineCommitted {
        val envelope = gson.fromJson(dataJson, JsonObject::class.java)
        val eventJson = envelope.get("data")
            ?.takeIf { it.isJsonObject }
            ?.asJsonObject
            ?: envelope
        return AgentStreamEvent.TimelineCommitted(
            ConversationTimelineWireMapper.toDomain(
                gson.fromJson(eventJson, ConversationTimelineEventDto::class.java)
            )
        )
    }

    private fun parseRawAgentEvent(
        event: String,
        map: Map<String, Any?>,
        dataJson: String
    ): AgentStreamEvent? {
        return when (event) {
            "text_delta" -> AgentStreamEvent.TextDelta(map["text"]?.toString().orEmpty())
            "thinking_delta" -> AgentStreamEvent.ThinkingDelta(map["text"]?.toString().orEmpty())
            "thinking_done" -> AgentStreamEvent.ThinkingDone(
                (map["durationMs"] as? Number)?.toLong() ?: 0L
            )
            "tool_call_start" -> AgentStreamEvent.ToolCallStart(
                id = map["id"]?.toString().orEmpty(),
                name = map["name"]?.toString().orEmpty(),
                argsPartial = map["argsPartial"]?.toString().orEmpty()
            )
            "tool_call_complete" -> AgentStreamEvent.ToolCallComplete(
                id = map["id"]?.toString().orEmpty(),
                name = map["name"]?.toString().orEmpty(),
                args = map["args"]?.toString().orEmpty(),
                result = map["result"]?.toString().orEmpty()
            )
            "signal" -> AgentStreamEvent.Signal(gson.fromJson(dataJson, AgentChatResponse::class.java))
            "final" -> AgentStreamEvent.Final(gson.fromJson(dataJson, AgentChatResponse::class.java))
            "error" -> parseFailure(
                message = map["message"]?.toString() ?: "服务异常",
                data = agentClientDataMap(map["data"])
            )
            "done" -> AgentStreamEvent.Done
            "heartbeat" -> AgentStreamEvent.Heartbeat
            else -> null
        }
    }

    private fun parseClientAgentEvent(event: String, map: Map<String, Any?>): AgentStreamEvent? {
        if (event == "heartbeat") return AgentStreamEvent.Heartbeat
        val sessionId = map["sessionId"]?.toString().orEmpty()
        val displayMessage = map["displayMessage"]?.toString().orEmpty()
        val data = agentClientDataMap(map["data"])
        val pendingToolCallId = data["pendingToolCallId"]?.toString()

        return when (event) {
            "task_started" -> null
            "tool_card" -> parseToolCardEvent(displayMessage, data)
            "scene_detected",
            "search_started",
            "search_result_ready",
            "pre_call_checking" -> AgentStreamEvent.ThinkingDelta(displayMessage)

            "call_started",
            "call_status_changed",
            "call_finished" -> AgentStreamEvent.StatusDelta(
                text = displayMessage,
                batchId = data["batchId"]?.toString()?.takeIf { it.isNotBlank() },
                itemIndex = (agentClientLong(data["itemIndex"]) ?: 0L).toInt(),
                total = (agentClientLong(data["total"]) ?: 0L).toInt(),
                targetName = data["targetName"]?.toString().orEmpty(),
                phoneNumber = data["phoneNumber"]?.toString().orEmpty(),
                batchStatus = data["status"]?.toString()?.takeIf { it.isNotBlank() },
                progressOnly = agentClientBoolean(data["progressOnly"])
            )

            "slot_updated" -> parseSlotUpdated(sessionId, displayMessage, data)
            "ask_user" -> AgentStreamEvent.Signal(
                AgentChatResponse(
                    sessionId = sessionId,
                    type = "ASK_USER",
                    text = displayMessage,
                    questions = agentFromJsonValue(gson, data["questions"], AskQuestionsPayload::class.java),
                    pendingToolCallId = pendingToolCallId
                )
            )
            "options_available" -> AgentStreamEvent.Signal(
                AgentChatResponse(
                    sessionId = sessionId,
                    type = "SHOW_OPTIONS",
                    text = displayMessage,
                    options = agentFromJsonValue(gson, data["options"], OptionsPayload::class.java),
                    pendingToolCallId = pendingToolCallId
                )
            )
            "request_permission" -> AgentStreamEvent.Signal(
                AgentChatResponse(
                    sessionId = sessionId,
                    type = "REQUEST_PERMISSION",
                    text = displayMessage,
                    permissionRequest = agentPermissionRequestFromClientData(data),
                    pendingToolCallId = pendingToolCallId
                )
            )
            "import_document_request" -> AgentStreamEvent.Signal(
                AgentChatResponse(
                    sessionId = sessionId,
                    type = "IMPORT_DOCUMENT_REQUEST",
                    text = displayMessage,
                    documentImportRequest = agentDocumentImportRequestFromClientData(data),
                    pendingToolCallId = pendingToolCallId
                )
            )
            "call_ready" -> AgentStreamEvent.Signal(
                AgentChatResponse(
                    sessionId = sessionId,
                    type = "MAKE_CALL_REQUEST",
                    text = displayMessage,
                    callSpec = agentCallSpecFromClientData(data),
                    pendingToolCallId = pendingToolCallId
                )
            )
            "lookup_contact_request",
            "agent_lookup_contact" -> AgentStreamEvent.Signal(
                AgentChatResponse(
                    sessionId = sessionId,
                    type = "LOOKUP_CONTACT_REQUEST",
                    text = displayMessage,
                    lookupContactPhone = data["phone"]?.toString().orEmpty(),
                    pendingToolCallId = pendingToolCallId
                )
            )
            "agent_lookup_device_contacts_by_names" -> AgentStreamEvent.Signal(
                AgentChatResponse(
                    sessionId = sessionId,
                    type = "LOOKUP_DEVICE_CONTACTS_BY_NAMES_REQUEST",
                    text = displayMessage,
                    lookupDeviceContactsByNames = LookupDeviceContactsByNamesPayload(
                        names = agentClientStringList(data["names"]),
                        reason = data["reason"]?.toString()?.takeIf { it.isNotBlank() }
                    ),
                    pendingToolCallId = pendingToolCallId
                )
            )
            "task_completed" -> parseTaskCompleted(event, sessionId, displayMessage, data)
            "task_failed" -> parseTaskFailed(event, sessionId, displayMessage, data)
            else -> null
        }
    }

    private fun parseSlotUpdated(
        sessionId: String,
        displayMessage: String,
        data: Map<String, Any?>
    ): AgentStreamEvent {
        val text = data["text"]?.toString()?.takeIf { it.isNotBlank() } ?: displayMessage
        return when {
            agentClientBoolean(data["progressOnly"]) -> AgentStreamEvent.ThinkingDelta(text)
            text.isBlank() -> AgentStreamEvent.ThinkingDelta(displayMessage)
            else -> AgentStreamEvent.Final(
                AgentChatResponse(
                    sessionId = sessionId,
                    type = "TEXT_REPLY",
                    text = text
                )
            )
        }
    }

    private fun parseTaskCompleted(
        event: String,
        sessionId: String,
        displayMessage: String,
        data: Map<String, Any?>
    ): AgentStreamEvent.Final {
        val rawCallResult = data["callResult"]
        val callResult = agentFromJsonValue(gson, rawCallResult, CallResultPayload::class.java)
        val rawBatchCallResult = data["batchCallResult"]
        val batchCallResult = agentFromJsonValue(gson, rawBatchCallResult, BatchCallResultPayload::class.java)
        terminalCallResultLogger(event, sessionId, displayMessage, rawCallResult, callResult, data)
        return AgentStreamEvent.Final(
            AgentChatResponse(
                sessionId = sessionId,
                type = when {
                    batchCallResult != null -> "BATCH_CALL_RESULT"
                    callResult != null -> "CALL_RESULT"
                    else -> "TEXT_REPLY"
                },
                text = agentCallResultDisplayText(displayMessage, callResult),
                callResult = callResult,
                batchCallResult = batchCallResult
            )
        )
    }

    private fun parseTaskFailed(
        event: String,
        sessionId: String,
        displayMessage: String,
        data: Map<String, Any?>
    ): AgentStreamEvent {
        val rawCallResult = data["callResult"]
        val callResult = agentFromJsonValue(gson, rawCallResult, CallResultPayload::class.java)
        terminalCallResultLogger(event, sessionId, displayMessage, rawCallResult, callResult, data)
        return if (callResult != null) {
            AgentStreamEvent.Final(
                AgentChatResponse(
                    sessionId = sessionId,
                    type = "CALL_RESULT",
                    text = agentCallResultDisplayText(displayMessage, callResult),
                    callResult = callResult
                )
            )
        } else {
            parseFailure(displayMessage.ifBlank { "服务异常" }, data)
        }
    }

    private fun parseFailure(
        message: String,
        data: Map<String, Any?>
    ): AgentStreamEvent.Err {
        return AgentStreamEvent.Err(
            message = message,
            errorCode = data["errorCode"]?.toString()?.takeIf { it.isNotBlank() },
            category = data["category"]?.toString()?.takeIf { it.isNotBlank() },
            retryable = data["retryable"]?.let(::agentClientBoolean),
            recoveryAction = data["recoveryAction"]?.toString()?.takeIf { it.isNotBlank() },
            traceId = data["traceId"]?.toString()?.takeIf { it.isNotBlank() },
            stage = data["stage"]?.toString()?.takeIf { it.isNotBlank() }
        )
    }

    private fun parseToolCardEvent(displayMessage: String, data: Map<String, Any?>): AgentStreamEvent.ToolCard {
        val methodLabel = data["methodLabel"]?.toString()?.takeIf { it.isNotBlank() }
            ?: data["toolName"]?.toString()?.takeIf { it.isNotBlank() }
            ?: "tool()"
        val body = data["body"]?.toString()?.takeIf { it.isNotBlank() }
            ?: agentConditionsToBody(data["conditions"])
        val result = data["result"]?.toString()?.takeIf { it.isNotBlank() } ?: displayMessage
        return AgentStreamEvent.ToolCard(
            ToolCardInfo(
                id = data["toolCallId"]?.toString().orEmpty(),
                toolName = data["toolName"]?.toString().orEmpty(),
                methodLabel = methodLabel,
                body = body,
                result = result,
                status = data["status"]?.toString().orEmpty()
            )
        )
    }

    private fun isAgentClientEvent(event: String): Boolean {
        return event in setOf(
            "task_started",
            "scene_detected",
            "search_started",
            "search_result_ready",
            "slot_updated",
            "ask_user",
            "options_available",
            "request_permission",
            "import_document_request",
            "lookup_contact_request",
            "agent_lookup_contact",
            "agent_lookup_device_contacts_by_names",
            "pre_call_checking",
            "call_ready",
            "call_started",
            "call_status_changed",
            "call_finished",
            "tool_card",
            "task_failed",
            "task_completed"
            ,"timeline_committed"
        )
    }

    private fun isRawAgentEvent(event: String): Boolean {
        return event in setOf(
            "text_delta",
            "thinking_delta",
            "thinking_done",
            "tool_call_start",
            "tool_call_complete",
            "signal",
            "final",
            "error",
            "done"
        )
    }
}
