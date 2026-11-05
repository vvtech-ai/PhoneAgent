package com.vvtech.phone_agent

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.telephony.SubscriptionManager
import android.telephony.TelephonyManager
import androidx.core.content.ContextCompat
import com.weway.chaken.incallsdk.utils.SIMUtil

/** Fixed reference order, including null versus blank SDK fallback. */
internal class TrustedCallerSimDeviceReader(context: Context) {
    private val application = context.applicationContext
    private fun canReadSubscription() = TrustedCallerSimReadPolicy.canReadSubscription(
        ContextCompat.checkSelfPermission(application, Manifest.permission.READ_PHONE_STATE) == PackageManager.PERMISSION_GRANTED,
        ContextCompat.checkSelfPermission(application, Manifest.permission.READ_PHONE_NUMBERS) == PackageManager.PERMISSION_GRANTED
    )
    @SuppressLint("MissingPermission")
    fun plan(loginPhone: String): List<TrustedCallerSimWrite> {
        if (TrustedCallerSimPlan.normalize(loginPhone).isBlank()) return emptyList()
        val subscriptions = application.getSystemService(SubscriptionManager::class.java)
        val active = if (!canReadSubscription()) emptyList() else
            runCatching { subscriptions?.activeSubscriptionInfoList.orEmpty() }.getOrDefault(emptyList())
        val sdkSlots = listOf(0, 1).filter { slot ->
            runCatching { SIMUtil.getSimStateBySlotIdx(application, slot) }.getOrDefault(false)
        }
        val slots = (sdkSlots + active.map { it.simSlotIndex }).filter { it >= 0 }.distinct().sorted()
        val numbers = slots.associateWith { slot ->
            TrustedCallerSimReadPolicy.readNumber(
                local = { runCatching { SIMUtil.getLocalPhoneNumber(application, slot) }.getOrNull() },
                sim = { runCatching { SIMUtil.getSimPhoneNumber(application, slot) }.getOrNull() },
                subscription = { readSubscription(subscriptions, slot) }
            )
        }
        return TrustedCallerSimPlan.writes(loginPhone, slots, numbers)
    }
    @SuppressLint("MissingPermission", "HardwareIds")
    @Suppress("DEPRECATION")
    private fun readSubscription(manager: SubscriptionManager?, slot: Int): String? {
        if (!canReadSubscription() || manager == null) return null
        val info = runCatching { manager.getActiveSubscriptionInfoForSimSlotIndex(slot) }.getOrNull() ?: return null
        val stored = runCatching { info.number }.getOrNull()
        if (!stored.isNullOrBlank()) return stored
        val telephony = application.getSystemService(TelephonyManager::class.java) ?: return null
        return runCatching { telephony.createForSubscriptionId(info.subscriptionId).line1Number }.getOrNull()
    }
}
