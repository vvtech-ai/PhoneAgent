package com.vvtech.aiassistant.callengine

import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.SocketException
import java.net.SocketTimeoutException

internal class AssistantSipSocket(account: AssistantSipAccount) : AutoCloseable {
    private val serverAddress =
        InetSocketAddress(InetAddress.getByName(account.server), account.port)
    val signaling = DatagramSocket().apply {
        connect(serverAddress)
        soTimeout = DefaultTimeoutMillis
    }
    val media = DatagramSocket()
    val localIp: String = signaling.localAddress.hostAddress ?: "127.0.0.1"
    val localSipPort: Int = signaling.localPort
    val localRtpPort: Int = media.localPort

    @Synchronized
    fun send(payload: String) {
        val bytes = payload.toByteArray(Charsets.UTF_8)
        signaling.send(DatagramPacket(bytes, bytes.size, serverAddress))
    }

    fun receive(timeoutMillis: Int = DefaultTimeoutMillis): AssistantSipMessage? {
        val previousTimeout = signaling.soTimeout
        signaling.soTimeout = timeoutMillis
        return try {
            val buffer = ByteArray(BufferSize)
            val packet = DatagramPacket(buffer, buffer.size)
            signaling.receive(packet)
            AssistantSipMessageParser.parse(
                String(packet.data, 0, packet.length, Charsets.UTF_8)
            )
        } catch (_: SocketTimeoutException) {
            null
        } catch (error: SocketException) {
            if (signaling.isClosed) null else throw error
        } finally {
            if (!signaling.isClosed) runCatching { signaling.soTimeout = previousTimeout }
        }
    }

    override fun close() {
        runCatching { media.close() }
        runCatching { signaling.close() }
    }

    private companion object {
        const val DefaultTimeoutMillis = 3_000
        const val BufferSize = 8_192
    }
}
