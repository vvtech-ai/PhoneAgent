package com.vvtech.phone_agent

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.net.DatagramSocket
import java.net.InetAddress
import java.net.InetSocketAddress
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/** UDP connect chooses a kernel route; it sends no signaling or media. */
class SipRouteChannel(messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "phone_agent/sip_route")
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val closed = AtomicBoolean(false)
    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "resolve") { result.notImplemented(); return@setMethodCallHandler }
            val host = call.argument<String>("host")
            val port = call.argument<Int>("port")
            if (host == null || host.length > 253 || !host.matches(Regex("^[A-Za-z0-9.:-]+$")) ||
                port == null || port !in 1..65535 || closed.get()) {
                result.error("sip_route_unavailable", "SIP网络不可用", null)
                return@setMethodCallHandler
            }
            worker.execute {
                val route = runCatching {
                    InetAddress.getAllByName(host).firstNotNullOfOrNull { peer ->
                        if (closed.get() || peer.isAnyLocalAddress || peer.isMulticastAddress) null
                        else runCatching {
                            DatagramSocket().use { socket ->
                                socket.connect(InetSocketAddress(peer, port))
                                val local = socket.localAddress
                                if (local.isAnyLocalAddress || local.isMulticastAddress) null
                                else mapOf("localAddress" to local.hostAddress,
                                    "peerAddress" to peer.hostAddress)
                            }
                        }.getOrNull()
                    }
                }.getOrNull()
                main.post {
                    if (route == null || closed.get()) result.error("sip_route_unavailable", "SIP网络不可用", null)
                    else result.success(route)
                }
            }
        }
    }
    fun close() {
        closed.set(true)
        channel.setMethodCallHandler(null)
        worker.shutdownNow()
    }
}
