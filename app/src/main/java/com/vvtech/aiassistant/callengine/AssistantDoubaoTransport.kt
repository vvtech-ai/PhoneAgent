package com.vvtech.aiassistant.callengine

import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import okio.ByteString

internal interface AssistantDoubaoTransport : AutoCloseable {
    fun connect(
        url: String,
        headers: Map<String, String>,
        listener: AssistantDoubaoTransportListener
    )
    fun send(payload: ByteArray)
}

internal interface AssistantDoubaoTransportListener {
    fun onOpen()
    fun onBinary(payload: ByteArray)
    fun onFailure(message: String)
    fun onClosed()
}

internal class OkHttpAssistantDoubaoTransport : AssistantDoubaoTransport {
    private val client = OkHttpClient()
    private var socket: WebSocket? = null

    override fun connect(
        url: String,
        headers: Map<String, String>,
        listener: AssistantDoubaoTransportListener
    ) {
        val request = Request.Builder().url(url).apply {
            headers.forEach { (name, value) -> header(name, value) }
        }.build()
        socket = client.newWebSocket(
            request,
            object : WebSocketListener() {
                override fun onOpen(webSocket: WebSocket, response: Response) = listener.onOpen()

                override fun onMessage(webSocket: WebSocket, bytes: ByteString) {
                    listener.onBinary(bytes.toByteArray())
                }

                override fun onFailure(
                    webSocket: WebSocket,
                    t: Throwable,
                    response: Response?
                ) = listener.onFailure(t.message ?: "Doubao AST 连接失败")

                override fun onClosed(webSocket: WebSocket, code: Int, reason: String) =
                    listener.onClosed()
            }
        )
    }

    override fun send(payload: ByteArray) {
        socket?.send(ByteString.of(*payload))
    }

    override fun close() {
        socket?.close(1000, "done")
        socket = null
        client.dispatcher.executorService.shutdown()
    }
}
