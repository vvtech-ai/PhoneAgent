package com.vvtech.phone_agent

import android.app.Activity
import android.content.Intent
import io.flutter.plugin.common.MethodChannel
import com.weway.chaken.incallsdk.ChakenIncallSdk

/** Transport only: SDK owns its Activity stack and return lifecycle. */
internal class TrustedCallerSdkRuntime(
    private val host: Activity,
    private val simBridge: TrustedCallerSimBridge,
    private val consumer: Long
) {
    private val registry = TrustedCallerSurfaceRegistry()
    private var initialized = false

    fun prepare(surface: TrustedCallerSurface, linked: Boolean, result: MethodChannel.Result) {
        if (!simBridge.current(surface, consumer)) {
            result.error("SDK_ACCOUNT_UNCONFIRMED", "SDK account is unavailable", null)
            return
        }
        if (!registry.isCurrent(surface)) {
            registry.bind(surface)
        }
        if (!linked) {
            result.error("SDK_RUNTIME_MISSING", "SDK runtime is unavailable", null)
            return
        }
        if (TrustedCallerConfiguration.read(surface.environment) == null) {
            result.error("SDK_CREDENTIALS_MISSING", "SDK credentials are unavailable", null)
            return
        }
        try {
            if (!initialized) {
                initialized = TrustedCallerIncomingRuntime.shared(host.application).ensureInitialized(surface.environment)
                if (!initialized) {
                    result.error(TrustedCallerIncomingRuntime.shared(host.application).initializationFailureCode, "SDK initialization failed", null)
                    return
                }
            }
            result.success(surface.report(mapOf("linked" to true, "configured" to true, "sdkVersion" to "1.5")))
        } catch (_: LinkageError) {
            result.error("SDK_PREPARE_FAILED", "SDK initialization failed", null)
        } catch (_: Exception) {
            result.error("SDK_PREPARE_FAILED", "SDK initialization failed", null)
        }
    }

    fun readStatus(surface: TrustedCallerSurface, result: MethodChannel.Result) {
        if (!ready(surface, result)) return
        result.success(surface.report(mapOf("status" to "readyToConfigure", "explicitSdkAuthorization" to false)))
    }

    fun open(surface: TrustedCallerSurface, result: MethodChannel.Result) {
        if (!ready(surface, result)) return
        // Reference sync is best-effort; no SIM must not block the SDK permissions UI.
        simBridge.synchronize(surface, consumer)
        val prefs = host.getSharedPreferences("trusted_caller_presentation", Activity.MODE_PRIVATE)
        try {
            if (!TrustedCallerGuidePolicy.seen(prefs.all)) {
                prefs.edit().putBoolean(TrustedCallerGuidePolicy.KEY, true).apply()
                ChakenIncallSdk.getInstance().openIncallUi(host)
            } else {
                try {
                    host.startActivity(Intent().setClassName(host.packageName, "com.weway.chaken.incallsdk.SettingActivity"))
                } catch (_: Exception) {
                    ChakenIncallSdk.getInstance().openIncallUi(host)
                }
            }
            result.success(surface.report())
        } catch (_: LinkageError) {
            result.error("SDK_OPEN_FAILED", "SDK launch failed", null)
        } catch (_: Exception) {
            result.error("SDK_OPEN_FAILED", "SDK launch failed", null)
        }
    }

    fun release(surface: TrustedCallerSurface) { registry.release(surface) }
    fun onAccountChanged(owner: TrustedCallerAccountOwner?) {
        val current = registry.current ?: return
        if (owner?.matches(current) != true) registry.release(current)
    }
    fun close() { registry.current?.let { registry.release(it) } }

    private fun ready(surface: TrustedCallerSurface, result: MethodChannel.Result): Boolean {
        if (initialized && registry.isCurrent(surface) && simBridge.current(surface, consumer)) return true
        result.error("SDK_NOT_CONFIGURED", "SDK surface is unavailable", null)
        return false
    }
}
