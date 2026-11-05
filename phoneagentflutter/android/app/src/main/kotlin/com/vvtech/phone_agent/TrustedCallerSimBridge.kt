package com.vvtech.phone_agent

import android.content.Context
import android.os.Looper
import com.weway.chaken.incallsdk.utils.SPUtil

internal class TrustedCallerSimBridge private constructor(context: Context) {
    private val reader = TrustedCallerSimDeviceReader(context)
    private val state = TrustedCallerSimAccountState { slot, number ->
        val normalized = TrustedCallerSimPlan.normalize(number)
        if (normalized.isNotBlank()) {
            val key = "SIM$slot"
            val usedSet = runCatching {
                val method = SPUtil::class.java.methods.firstOrNull {
                    it.name == "set" && it.parameterTypes.size == 2 &&
                        it.parameterTypes[0] == String::class.java
                } ?: return@runCatching false
                method.invoke(null, key, normalized)
                true
            }.getOrDefault(false)
            if (!usedSet) SPUtil.put(key, normalized)
        }
    }
    private fun serialized() { check(Looper.myLooper() == Looper.getMainLooper()) { "SIM bridge thread invalid" } }
    fun attachConsumer(): Long { serialized(); return state.attachConsumer() }
    fun updateAccount(owner: TrustedCallerAccountOwner?, consumer: Long): Boolean {
        serialized(); return state.updateAccount(owner, consumer)
    }
    fun current(surface: TrustedCallerSurface, consumer: Long): Boolean {
        serialized(); return state.current(surface, consumer)
    }
    fun synchronize(surface: TrustedCallerSurface, consumer: Long): Boolean {
        serialized()
        if (!current(surface, consumer)) return false
        return try { state.synchronize(surface, consumer, reader.plan(surface.phone)) }
        catch (_: Exception) { false } catch (_: LinkageError) { false }
    }
    fun synchronizeAccount(owner: TrustedCallerAccountOwner, consumer: Long): Boolean {
        val surface = TrustedCallerSurface("0".repeat(32), owner.accountId, owner.phone, owner.loginEpoch, owner.environment)
        return synchronize(surface, consumer)
    }
    fun detachConsumer(consumer: Long) { serialized(); state.detachConsumer(consumer) }
    companion object {
        private var instance: TrustedCallerSimBridge? = null
        fun shared(context: Context): TrustedCallerSimBridge {
            check(Looper.myLooper() == Looper.getMainLooper()) { "SIM bridge thread invalid" }
            return instance ?: TrustedCallerSimBridge(context.applicationContext).also { instance = it }
        }
    }
}
