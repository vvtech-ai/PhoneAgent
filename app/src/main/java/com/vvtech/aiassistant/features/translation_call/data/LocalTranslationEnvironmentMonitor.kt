package com.vvtech.aiassistant.features.translation_call.data

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import com.vvtech.aiassistant.domain.translation.TranslationEnvironmentComponent
import com.vvtech.aiassistant.domain.translation.TranslationEnvironmentState
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText

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
            ?: return unavailable(currentAppText("当前无可用网络", "No network is currently available"))
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
                onNetworkChanged(unavailable(currentAppText("网络连接已断开", "Network connection was lost")))
            }
        }
        callback = next
        runCatching { connectivityManager.registerDefaultNetworkCallback(next) }
            .onFailure {
                callback = null
                onNetworkChanged(unavailable(currentAppText("无法监听网络状态", "Unable to monitor network status")))
            }
    }

    override fun stop() {
        callback?.let { runCatching { connectivityManager.unregisterNetworkCallback(it) } }
        callback = null
    }

    private fun capabilitiesState(
        capabilities: NetworkCapabilities?
    ): TranslationEnvironmentComponent {
        if (capabilities == null) return unavailable(currentAppText("网络能力不可用", "Network capabilities are unavailable"))
        val internet = capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
        val validated = capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
        return when {
            !internet -> unavailable(currentAppText("当前网络无法访问互联网", "The current network cannot access the internet"))
            !validated -> TranslationEnvironmentComponent(
                TranslationEnvironmentState.Degraded,
                detail = currentAppText(
                    "网络尚未完成可用性验证",
                    "Network availability has not been fully verified"
                )
            )
            else -> TranslationEnvironmentComponent(TranslationEnvironmentState.Available)
        }
    }

    private fun unavailable(detail: String) = TranslationEnvironmentComponent(
        TranslationEnvironmentState.Unavailable,
        detail = detail
    )
}
