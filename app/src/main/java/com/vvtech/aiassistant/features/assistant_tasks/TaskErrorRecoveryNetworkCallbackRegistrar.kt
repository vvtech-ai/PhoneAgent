package com.vvtech.aiassistant.features.assistant_tasks

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import com.vvtech.aiassistant.logging.AppFileLogger

internal class TaskErrorRecoveryNetworkCallbackRegistrar(
    appContext: Context,
    private val warn: (String) -> Unit = { message -> AppFileLogger.w("Index9VM", message) }
) {
    private val connectivityManager: ConnectivityManager? =
        appContext.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
    private var registered = false
    private var networkCallback: ConnectivityManager.NetworkCallback? = null

    fun register(onAvailable: () -> Unit) {
        val manager = connectivityManager ?: return
        if (registered) return
        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                onAvailable()
            }
        }
        runCatching {
            manager.registerDefaultNetworkCallback(callback)
            networkCallback = callback
            registered = true
        }.onFailure { throwable ->
            warn("register task error network callback failed: ${throwable.message}")
        }
    }

    fun unregister() {
        val manager = connectivityManager ?: return
        if (!registered) return
        val callback = networkCallback ?: return
        runCatching {
            manager.unregisterNetworkCallback(callback)
            networkCallback = null
            registered = false
        }.onFailure { throwable ->
            warn("unregister task error network callback failed: ${throwable.message}")
        }
    }
}
