package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.logging.AppFileLogger

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.SubscriptionInfo
import android.telephony.SubscriptionManager
import android.telephony.TelephonyManager
import androidx.core.content.ContextCompat

private const val TrustedCalleeSimNumberBridgeTag = "TrustedCalleeSimBridge"
private const val PrimarySimSlot = 0
private const val SecondarySimSlot = 1

internal fun syncTrustedCalleeSimNumbersForLogin(
    context: Context,
    loginPhone: String
): TrustedCalleeSimNumberSyncResult {
    val appContext = context.applicationContext
    val loginNumber = normalizeTrustedCalleePhone(loginPhone)
    if (loginNumber.isBlank()) {
        return TrustedCalleeSimNumberSyncResult.NoLoginNumber
    }

    val activeSlots = detectActiveSimSlots(appContext)
    return when (activeSlots.size) {
        0 -> {
            AppFileLogger.i(TrustedCalleeSimNumberBridgeTag, "No active SIM detected, skip trusted callee SIM number sync.")
            TrustedCalleeSimNumberSyncResult.NoSim
        }

        1 -> {
            val slotIndex = activeSlots.first()
            val cardNumber = readSimPhoneNumber(appContext, slotIndex)
            val numberToWrite = cardNumber.ifBlank { loginNumber }
            writeTrustedCalleeSimNumber(slotIndex, numberToWrite)
            TrustedCalleeSimNumberSyncResult.SingleSim(slotIndex, numberToWrite, cardNumber.isBlank())
        }

        else -> {
            val normalizedSlots = activeSlots.distinct().sorted()
            val slotNumbers = normalizedSlots.associateWith { slotIndex ->
                readSimPhoneNumber(appContext, slotIndex)
            }
            val writes = mutableListOf<TrustedCalleeSimWrite>()

            slotNumbers
                .filterValues { it.isNotBlank() }
                .forEach { (slotIndex, cardNumber) ->
                    writeTrustedCalleeSimNumber(slotIndex, cardNumber)
                    writes += TrustedCalleeSimWrite(slotIndex, cardNumber, fallback = false)
                }

            val fallbackSlot = normalizedSlots.firstOrNull { it == SecondarySimSlot }
                ?: normalizedSlots.last()
            if (slotNumbers[fallbackSlot].isNullOrBlank()) {
                writeTrustedCalleeSimNumber(fallbackSlot, loginNumber)
                writes += TrustedCalleeSimWrite(fallbackSlot, loginNumber, fallback = true)
            }

            TrustedCalleeSimNumberSyncResult.DualSim(writes)
        }
    }
}

internal sealed interface TrustedCalleeSimNumberSyncResult {
    object NoLoginNumber : TrustedCalleeSimNumberSyncResult
    object NoSim : TrustedCalleeSimNumberSyncResult

    data class SingleSim(
        val slotIndex: Int,
        val number: String,
        val fallback: Boolean
    ) : TrustedCalleeSimNumberSyncResult

    data class DualSim(
        val writes: List<TrustedCalleeSimWrite>
    ) : TrustedCalleeSimNumberSyncResult
}

internal data class TrustedCalleeSimWrite(
    val slotIndex: Int,
    val number: String,
    val fallback: Boolean
)

private fun detectActiveSimSlots(context: Context): List<Int> {
    val sdkSlots = listOf(PrimarySimSlot, SecondarySimSlot)
        .filter { slotIndex ->
            invokeOptionalSimBoolean(context, "getSimStateBySlotIdx", slotIndex)
        }
    val subscriptionSlots = activeSubscriptionSlots(context)
    return (sdkSlots + subscriptionSlots)
        .distinct()
        .sorted()
}

@SuppressLint("MissingPermission")
private fun activeSubscriptionSlots(context: Context): List<Int> {
    if (!hasPhoneReadPermission(context)) return emptyList()
    val subscriptionManager = context.getSystemService(SubscriptionManager::class.java) ?: return emptyList()
    return runCatching {
        subscriptionManager.activeSubscriptionInfoList
            .orEmpty()
            .map { it.simSlotIndex }
            .filter { it >= 0 }
    }.getOrDefault(emptyList())
}

private fun readSimPhoneNumber(context: Context, slotIndex: Int): String {
    val sdkNumber = normalizeTrustedCalleePhone(
        invokeOptionalSimString(context, "getLocalPhoneNumber", slotIndex)
            ?: invokeOptionalSimString(context, "getSimPhoneNumber", slotIndex)
    )
    if (sdkNumber.isNotBlank()) return sdkNumber

    return normalizeTrustedCalleePhone(readSubscriptionPhoneNumber(context, slotIndex))
}

@SuppressLint("MissingPermission", "HardwareIds")
private fun readSubscriptionPhoneNumber(context: Context, slotIndex: Int): String? {
    if (!hasPhoneReadPermission(context)) return null
    val subscriptionInfo = subscriptionInfoForSlot(context, slotIndex) ?: return null
    val infoNumber = runCatching { subscriptionInfo.number }.getOrNull()
    if (!infoNumber.isNullOrBlank()) return infoNumber

    val telephonyManager = context.getSystemService(TelephonyManager::class.java) ?: return null
    return runCatching {
        telephonyManager
            .createForSubscriptionId(subscriptionInfo.subscriptionId)
            .line1Number
    }.getOrNull()
}

@SuppressLint("MissingPermission")
private fun subscriptionInfoForSlot(context: Context, slotIndex: Int): SubscriptionInfo? {
    val subscriptionManager = context.getSystemService(SubscriptionManager::class.java) ?: return null
    return runCatching {
        subscriptionManager.getActiveSubscriptionInfoForSimSlotIndex(slotIndex)
    }.getOrNull()
}

private fun writeTrustedCalleeSimNumber(slotIndex: Int, number: String) {
    val normalized = normalizeTrustedCalleePhone(number)
    if (normalized.isBlank()) return
    val key = "SIM$slotIndex"
    val usedSetMethod = runCatching {
        val preferences = Class.forName(OptionalSpUtilClass)
        val setMethod = preferences.methods.firstOrNull { method ->
            method.name in setOf("set", "put") &&
                method.parameterTypes.size == 2 &&
                method.parameterTypes[0] == String::class.java
        } ?: return@runCatching false
        setMethod.invoke(null, key, normalized)
        true
    }.getOrDefault(false)
    AppFileLogger.i(
        TrustedCalleeSimNumberBridgeTag,
        "Trusted callee SIM sync attempted. key=$key phoneLast4=${normalized.takeLast(4)} sdkAvailable=$usedSetMethod"
    )
}

private fun invokeOptionalSimBoolean(context: Context, methodName: String, slotIndex: Int): Boolean =
    runCatching {
        val method = Class.forName(OptionalSimUtilClass).methods.first { method ->
            method.name == methodName && method.parameterCount == 2
        }
        method.invoke(null, context, slotIndex) as? Boolean ?: false
    }.getOrDefault(false)

private fun invokeOptionalSimString(context: Context, methodName: String, slotIndex: Int): String? =
    runCatching {
        val method = Class.forName(OptionalSimUtilClass).methods.first { method ->
            method.name == methodName && method.parameterCount == 2
        }
        method.invoke(null, context, slotIndex)?.toString()
    }.getOrNull()

private const val OptionalSimUtilClass = "com.weway.chaken.incallsdk.utils.SIMUtil"
private const val OptionalSpUtilClass = "com.weway.chaken.incallsdk.utils.SPUtil"

private fun hasPhoneReadPermission(context: Context): Boolean {
    val hasPhoneState = ContextCompat.checkSelfPermission(
        context,
        Manifest.permission.READ_PHONE_STATE
    ) == PackageManager.PERMISSION_GRANTED
    val hasPhoneNumbers = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
        ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.READ_PHONE_NUMBERS
        ) == PackageManager.PERMISSION_GRANTED
    return hasPhoneState || hasPhoneNumbers
}

private fun normalizeTrustedCalleePhone(raw: String?): String {
    var value = raw.orEmpty()
        .trim()
        .replace(Regex("\\s+"), "")
        .replace("-", "")
        .replace("(", "")
        .replace(")", "")
    when {
        value.startsWith("+86") -> value = value.substring(3)
        value.startsWith("0086") -> value = value.substring(4)
        value.startsWith("86") && value.length == 13 -> value = value.substring(2)
    }
    val digits = value.filter(Char::isDigit)
    return digits.takeIf { Regex("^1[3-9]\\d{9}$").matches(it) }.orEmpty()
}
