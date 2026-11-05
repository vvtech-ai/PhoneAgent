package com.vvtech.phone_agent

import android.app.Activity
import android.content.pm.ApplicationInfo
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Owner-scoped native SDK requests; credentials never cross the Flutter channel. */
class TrustedCallerChannel(context: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "phone_agent/trusted_caller")
    private val environment = TrustedCallerEnvironment.resolve(
        context.packageName,
        context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0
    )
    private val simBridge = TrustedCallerSimBridge.shared(context)
    private val consumer = simBridge.attachConsumer()
    private val runtime = TrustedCallerSdkRuntime(context, simBridge, consumer)
    private val incoming = TrustedCallerIncomingRuntime.shared(context)
    private val homeGuide = TrustedCallerHomeGuide(context)
    private val linked = try {
        Class.forName("com.weway.chaken.incallsdk.ChakenIncallSdk", false, context.classLoader)
        true
    } catch (_: Throwable) { false }

    init {
        incoming.attach(consumer)
        channel.setMethodCallHandler { call, result ->
            if (call.method == "updateAccount") {
                val args = call.arguments as? Map<*, *>
                val rawOwner = args?.get("owner")
                val owner = TrustedCallerAccountOwner.parse(rawOwner, environment)
                if (args == null || args["environment"] != environment ||
                    !args.containsKey("owner") || (rawOwner != null && owner == null)) {
                    result.error("SDK_ACCOUNT_INVALID", "Invalid SDK account", null)
                } else {
                    if (!incoming.suspend(consumer)) {
                        result.error("SDK_INCOMING_CLEANUP_UNCONFIRMED", "SDK consumer ownership unconfirmed", null)
                        return@setMethodCallHandler
                    }
                    runtime.onAccountChanged(owner)
                    val confirmed = simBridge.updateAccount(owner, consumer)
                    incoming.update(owner, consumer)
                    if (confirmed) result.success(null)
                    else result.error("SDK_SIM_CLEANUP_UNCONFIRMED", "SDK account cleanup unconfirmed", null)
                }
            } else if (call.method !in setOf("prepare", "readStatus", "openSettings", "releaseSurface", "readHomeGuide", "recordHomeGuide")) {
                result.notImplemented()
            } else {
                val surface = TrustedCallerSurface.parse(call.arguments)
                if (surface == null || surface.environment != environment) {
                    result.error("SDK_SURFACE_INVALID", "Invalid SDK surface", null)
                } else when (call.method) {
                    "readHomeGuide", "recordHomeGuide" -> {
                        if (!simBridge.current(surface, consumer)) {
                            result.error("SDK_ACCOUNT_UNCONFIRMED", "SDK account is unavailable", null)
                        } else if (call.method == "readHomeGuide") {
                            result.success(incoming.ensureInitialized(environment) && homeGuide.eligible())
                        } else {
                            val disabled = (call.arguments as? Map<*, *>)?.get("disabled") as? Boolean
                            if (disabled == null) result.error("SDK_INVALID_REPORT", "Invalid guide flag", null)
                            else if (homeGuide.record(disabled)) result.success(null)
                            else result.error("SDK_GUIDE_STORE_FAILED", "Guide record failed", null)
                        }
                    }
                    "prepare" -> runtime.prepare(surface, linked, result)
                    "readStatus" -> runtime.readStatus(surface, result)
                    "openSettings" -> runtime.open(surface, result)
                    "releaseSurface" -> { runtime.release(surface); result.success(null) }
                }
            }
        }
    }
    fun close() {
        incoming.suspend(consumer)
        runtime.close()
        simBridge.detachConsumer(consumer)
        channel.setMethodCallHandler(null)
    }
}
