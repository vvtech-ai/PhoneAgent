package com.vvtech.aiassistant.network

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities

internal fun Context.hasValidatedInternetAccess(): Boolean {
    val connectivityManager =
        applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            ?: return false
    val activeNetwork = connectivityManager.activeNetwork ?: return false
    val capabilities = connectivityManager.getNetworkCapabilities(activeNetwork) ?: return false
    return hasValidatedInternetCapabilities(
        hasInternetCapability =
            capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET),
        hasValidatedCapability =
            capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
    )
}

internal fun hasValidatedInternetCapabilities(
    hasInternetCapability: Boolean,
    hasValidatedCapability: Boolean
): Boolean = hasInternetCapability && hasValidatedCapability
