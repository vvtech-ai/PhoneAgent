package com.vvtech.aiassistant.data.repository

import com.vvtech.aiassistant.core.model.AgentChatRequest
import com.vvtech.aiassistant.core.model.AgentStreamEvent
import com.vvtech.aiassistant.data.service.AssistantApiService
import com.vvtech.aiassistant.logging.AppFileLogger
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOn

internal class AgentStreamRemoteDataSource(
    private val streamingApiService: AssistantApiService,
    private val eventParser: AgentStreamSseEventParser = AgentStreamSseEventParser()
) {
    fun stream(request: AgentChatRequest): Flow<AgentStreamEvent> = flow {
        AppFileLogger.d("TTS_DIAG", "agentChatStream: opening SSE connection")
        val body = streamingApiService.agentChatStream(request)
        AppFileLogger.d("TTS_DIAG", "agentChatStream: SSE body received, starting read loop")
        body.byteStream().bufferedReader(Charsets.UTF_8).use { reader ->
            var event: String? = null
            val data = StringBuilder()
            while (true) {
                val line = reader.readLine() ?: break
                if (line.isEmpty()) {
                    val ev = event
                    val payload = data.toString()
                    if (!ev.isNullOrBlank()) {
                        val clientEvent = eventParser.isClientLogEvent(ev)
                        val conversationEvent = eventParser.isConversationEvent(ev)
                        AppFileLogger.d(
                            "TTS_DIAG",
                            if (clientEvent) {
                                "agentChatStream: SSE event='$ev' payload=${payload.take(80)}"
                            } else {
                                "agentChatStream: dropped raw SSE event='$ev'"
                            }
                        )
                        if (clientEvent) {
                            logLong(
                                tag = "AgentSseFull",
                                header = "event=$ev payload",
                                value = payload
                            )
                        }
                        if (conversationEvent) {
                            AppFileLogger.logConversation(
                                direction = "sse",
                                source = ev,
                                message = payload
                            )
                        }
                        val parsed = eventParser.parse(ev, payload)
                        if (parsed != null) emit(parsed)
                        if (parsed is AgentStreamEvent.Done) break
                    }
                    event = null
                    data.setLength(0)
                    continue
                }
                when {
                    line.startsWith("event:") -> event = line.removePrefix("event:").trim()
                    line.startsWith("data:") -> {
                        if (data.isNotEmpty()) data.append('\n')
                        data.append(line.removePrefix("data:").trim())
                    }
                }
            }
        }
    }.flowOn(Dispatchers.IO)

    private fun logLong(tag: String, header: String, value: String) {
        val text = value.ifEmpty { "<empty>" }
        val chunkSize = 3000
        val total = (text.length + chunkSize - 1) / chunkSize
        AppFileLogger.d(tag, "$header len=${value.length} chunks=$total")
        text.chunked(chunkSize).forEachIndexed { index, chunk ->
            AppFileLogger.d(tag, "$header chunk=${index + 1}/$total $chunk")
        }
    }
}
