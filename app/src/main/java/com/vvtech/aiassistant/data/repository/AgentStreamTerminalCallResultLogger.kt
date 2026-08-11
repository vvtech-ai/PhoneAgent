package com.vvtech.aiassistant.data.repository

import com.vvtech.aiassistant.core.model.CallResultPayload
import com.vvtech.aiassistant.logging.AppFileLogger

private const val REPORT_CALL_OUTCOME_TAG = "ReportCallOutcome"

internal typealias AgentStreamTerminalCallResultLogger = (
    event: String,
    sessionId: String,
    displayMessage: String,
    rawCallResult: Any?,
    callResult: CallResultPayload?,
    data: Map<String, Any?>
) -> Unit

internal fun logAgentStreamTerminalCallResultEvent(
    event: String,
    sessionId: String,
    displayMessage: String,
    rawCallResult: Any?,
    callResult: CallResultPayload?,
    data: Map<String, Any?>
) {
    val metadata = callResult?.metadata.orEmpty()
    val rawType = rawCallResult?.javaClass?.simpleName ?: "null"
    val rawPreview = rawCallResult?.toString()?.take(500).orEmpty()
    val parsedOutcome = agentCallResultReportedOutcome(metadata)
    val logMessage = buildString {
        append("SSE terminal event=").append(event)
        append(" sessionId=").append(sessionId)
        append(" rawCallResultType=").append(rawType)
        append(" hasCallResult=").append(callResult != null)
        append(" status=").append(callResult?.status.orEmpty())
        append(" agentOutcome=").append(parsedOutcome)
        append(" resultCode=").append(metadata["resultCode"].orEmpty())
        append(" resultReason=").append(metadata["resultReason"].orEmpty().take(120))
        append(" agentReason=").append(metadata["agentReason"].orEmpty().take(120))
        append(" callId=").append(metadata["callId"].orEmpty())
        append(" taskId=").append(metadata["taskId"].orEmpty())
        append(" metadataKeys=").append(metadata.keys.joinToString(","))
        append(" dataKeys=").append(data.keys.joinToString(","))
        append(" displayMessage=").append(displayMessage.take(120))
    }
    if (rawCallResult != null && callResult == null) {
        AppFileLogger.w(REPORT_CALL_OUTCOME_TAG, "$logMessage rawPreview=$rawPreview")
    } else {
        AppFileLogger.i(REPORT_CALL_OUTCOME_TAG, logMessage)
    }
}
