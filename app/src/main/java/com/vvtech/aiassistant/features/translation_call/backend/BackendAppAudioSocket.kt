package com.vvtech.aiassistant.features.translation_call.backend

import java.util.concurrent.atomic.AtomicLong
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import com.vvtech.aiassistant.account.AccountIdentityProvider
import okio.ByteString

internal interface BackendAppAudioTransport {
    fun connect(
        wsUrl: String,
        callSessionId: String,
        listener: Listener
    )
    fun sendPcm16(pcmLittleEndian: ByteArray, sampleRate: Int): Boolean
    fun close()

    interface Listener {
        fun onOpen()
        fun onMessage(message: BackendRealtimeMessage)
        fun onError(message: String)
        fun onClosed()
    }
}

internal class BackendAppAudioSocket(
    private val client: OkHttpClient = SharedClient
) : BackendAppAudioTransport {
    private val sequence = AtomicLong()
    private var socket: WebSocket? = null

    override fun connect(
        wsUrl: String,
        callSessionId: String,
        listener: BackendAppAudioTransport.Listener
    ) {
        close()
        socket = client.newWebSocket(
            Request.Builder()
                .url(withBinaryDownlink(wsUrl))
                .header("Authorization", "Bearer ${AccountIdentityProvider.accessToken}")
                .build(),
            object : WebSocketListener() {
                override fun onOpen(webSocket: WebSocket, response: Response) {
                    webSocket.send(
                        BackendRealtimeProtocol.startFrame(
                            callSessionId = callSessionId,
                            sequence = sequence.getAndIncrement(),
                            timestampMs = System.currentTimeMillis()
                        )
                    )
                    listener.onOpen()
                }

                override fun onMessage(webSocket: WebSocket, text: String) {
                    parse({ BackendRealtimeProtocol.parseText(text) }, listener)
                }

                override fun onMessage(webSocket: WebSocket, bytes: ByteString) {
                    parse({ BackendRealtimeProtocol.parseBinary(bytes.toByteArray()) }, listener)
                }

                override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                    listener.onError(t.message ?: "实时音频 WebSocket 连接失败")
                }

                override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                    listener.onClosed()
                }
            }
        )
    }

    override fun sendPcm16(pcmLittleEndian: ByteArray, sampleRate: Int): Boolean {
        if (pcmLittleEndian.isEmpty()) return false
        return socket?.send(
            BackendRealtimeProtocol.mediaFrame(pcmLittleEndian, sampleRate)
        ) == true
    }

    override fun close() {
        socket?.send(BackendRealtimeProtocol.stopFrame())
        socket?.close(NormalClosureCode, "client hangup")
        socket = null
    }

    private fun parse(
        block: () -> BackendRealtimeMessage,
        listener: BackendAppAudioTransport.Listener
    ) {
        runCatching(block)
            .onSuccess(listener::onMessage)
            .onFailure { listener.onError(it.message ?: "实时协议消息解析失败") }
    }

    private fun withBinaryDownlink(url: String): String {
        if (url.contains("downlinkAudio=")) return url
        return url + if (url.contains("?")) "&downlinkAudio=binary" else "?downlinkAudio=binary"
    }

    private companion object {
        val SharedClient = OkHttpClient()
        const val NormalClosureCode = 1000
    }
}
