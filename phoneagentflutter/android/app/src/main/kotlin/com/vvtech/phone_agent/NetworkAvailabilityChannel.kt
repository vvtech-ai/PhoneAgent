package com.vvtech.phone_agent

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/** OS snapshots/events only; never probes URLs, requests networks or logs identifiers. */
class NetworkAvailabilityChannel(context: Context, messenger: BinaryMessenger) : EventChannel.StreamHandler {
    private val appContext = context.applicationContext
    private val channel = MethodChannel(messenger, "phone_agent/network_availability")
    private val events = EventChannel(messenger, "phone_agent/network_availability_events")
    private val main = Handler(Looper.getMainLooper())
    private val manager = appContext.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
    private var callback: ConnectivityManager.NetworkCallback? = null
    private var sink: EventChannel.EventSink? = null
    private var generation = 0

    init {
        events.setStreamHandler(this)
        channel.setMethodCallHandler { call, result ->
            if (call.method != "read") result.notImplemented()
            else result.success(read())
        }
    }

    private fun read(): String = try {
        val network = manager?.activeNetwork
        val caps = network?.let { manager.getNetworkCapabilities(it) }
        if (caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) == true &&
            caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)) "available"
        else "unavailable"
    } catch (_: Exception) {
        "unknown"
    }

    override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink) {
        stopWatch()
        sink = eventSink
        val owner = generation
        val observer = object : ConnectivityManager.NetworkCallback() {
            private fun publish() {
                if (generation == owner) sink?.success(read())
            }
            override fun onAvailable(network: Network) = publish()
            override fun onLost(network: Network) = publish()
            override fun onCapabilitiesChanged(network: Network, caps: NetworkCapabilities) = publish()
        }
        try {
            val connectivity = manager
            if (connectivity == null) eventSink.success("unknown")
            else {
                connectivity.registerDefaultNetworkCallback(observer, main)
                callback = observer
                eventSink.success(read())
            }
        } catch (_: Exception) {
            eventSink.success("unknown")
        }
    }

    override fun onCancel(arguments: Any?) = stopWatch()

    private fun stopWatch() {
        generation++
        sink = null
        val old = callback
        callback = null
        if (old != null) try { manager?.unregisterNetworkCallback(old) } catch (_: Exception) { }
    }

    fun close() {
        stopWatch()
        events.setStreamHandler(null)
        channel.setMethodCallHandler(null)
    }
}
