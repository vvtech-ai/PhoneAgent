package com.vvtech.aiassistant.data.local.voiceclone

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build

internal data class VoiceCloneVerificationEnvironment(
    val deviceModel: String,
    val networkType: String,
    val networkValidated: Boolean
)

internal fun interface VoiceCloneVerificationEnvironmentProvider {
    fun snapshot(): VoiceCloneVerificationEnvironment
}

internal class AndroidVoiceCloneVerificationEnvironmentProvider(
    context: Context
) : VoiceCloneVerificationEnvironmentProvider {
    private val connectivityManager = context.applicationContext
        .getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager

    override fun snapshot(): VoiceCloneVerificationEnvironment {
        val capabilities = runCatching {
            connectivityManager?.activeNetwork?.let(connectivityManager::getNetworkCapabilities)
        }.getOrNull()
        return VoiceCloneVerificationEnvironment(
            deviceModel = sanitizeVoiceCloneDeviceModel(Build.MODEL),
            networkType = selectVoiceCloneNetworkType(
                vpn = capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true,
                wifi = capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true,
                cellular = capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) == true,
                ethernet = capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) == true,
                connected = capabilities != null
            ),
            networkValidated = capabilities
                ?.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED) == true
        )
    }
}

internal fun sanitizeVoiceCloneDeviceModel(value: String?): String = value
    .orEmpty()
    .trim()
    .replace(Regex("\\s+"), " ")
    .take(MAX_DEVICE_MODEL_LENGTH)
    .ifBlank { "unknown" }

internal fun selectVoiceCloneNetworkType(
    vpn: Boolean,
    wifi: Boolean,
    cellular: Boolean,
    ethernet: Boolean,
    connected: Boolean
): String = when {
    vpn -> "VPN"
    wifi -> "WIFI"
    cellular -> "CELLULAR"
    ethernet -> "ETHERNET"
    connected -> "OTHER"
    else -> "NONE"
}

private const val MAX_DEVICE_MODEL_LENGTH = 64
