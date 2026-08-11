package com.vvtech.aiassistant.features.translation_call.data

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import com.vvtech.aiassistant.domain.translation.TranslationEnvironmentComponent
import com.vvtech.aiassistant.domain.translation.TranslationEnvironmentState

internal interface LocalTranslationEnvironmentMonitor {
    fun currentNetwork(): TranslationEnvironmentComponent
    fun start(onNetworkChanged: (TranslationEnvironmentComponent) -> Unit)
    fun stop()
}

internal class AndroidLocalTranslationEnvironmentMonitor(
    context: Context
) : LocalTranslationEnvironmentMonitor {
    private val connectivityManager =
        context.applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE)
            as ConnectivityManager
    private var callback: ConnectivityManager.NetworkCallback? = null

    override fun currentNetwork(): TranslationEnvironmentComponent {
        val activeNetwork = connectivityManager.activeNetwork
            ?: return unavailable("当前无可用网络")
        return capabilitiesState(connectivityManager.getNetworkCapabilities(activeNetwork))
    }

    override fun start(onNetworkChanged: (TranslationEnvironmentComponent) -> Unit) {
        stop()
        val next = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                onNetworkChanged(
                    capabilitiesState(connectivityManager.getNetworkCapabilities(network))
                )
            }

            override fun onCapabilitiesChanged(
                network: Network,
                networkCapabilities: NetworkCapabilities
            ) {
                onNetworkChanged(capabilitiesState(networkCapabilities))
            }

            override fun onLost(network: Network) {
                onNetworkChanged(unavailable("网络连接已断开"))
            }
        }
        callback = next
        runCatching { connectivityManager.registerDefaultNetworkCallback(next) }
            .onFailure {
                callback = null
                onNetworkChanged(unavailable("无法监听网络状态"))
            }
    }

    override fun stop() {
        callback?.let { runCatching { connectivityManager.unregisterNetworkCallback(it) } }
        callback = null
    }

    private fun capabilitiesState(
        capabilities: NetworkCapabilities?
    ): TranslationEnvironmentComponent {
        if (capabilities == null) return unavailable("网络能力不可用")
        val internet = capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
        val validated = capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
        return when {
            !internet -> unavailable("当前网络无法访问互联网")
            !validated -> TranslationEnvironmentComponent(
                TranslationEnvironmentState.Degraded,
                detail = "网络尚未完成可用性验证"
            )
            else -> TranslationEnvironmentComponent(TranslationEnvironmentState.Available)
        }
    }

    private fun unavailable(detail: String) = TranslationEnvironmentComponent(
        TranslationEnvironmentState.Unavailable,
        detail = detail
    )
}
