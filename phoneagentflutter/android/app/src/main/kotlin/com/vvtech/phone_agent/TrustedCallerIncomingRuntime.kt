package com.vvtech.phone_agent

import android.app.Application
import android.content.Context
import com.weway.chaken.incallsdk.ChakenIncallSdk
import com.weway.chaken.constant.Constants
import com.weway.chaken.net.HttpClient
import com.weway.chaken.net.HttpHeaders
import com.weway.chaken.net.HttpParams

/** Reference Application initialization; vendor owns receivers, role and switch. */
class TrustedCallerIncomingRuntime private constructor(private val app: Application) {
    private var consumer = 0L
    private var initializedEnvironment: String? = null
    internal fun attach(captured: Long) { if (captured > consumer) consumer = captured }
    internal fun suspend(captured: Long): Boolean = captured == consumer
    internal fun update(next: TrustedCallerAccountOwner?, captured: Long) {
        if (consumer != captured || next == null) return
        if (!ensureInitialized(next.environment)) return
        // Same SIM login synchronization, without changing the user's SDK settings.
        TrustedCallerSimBridge.shared(app).synchronizeAccount(next, captured)
    }

    internal fun initializeAtStartup() {
        restoreLegacyHostOverride()
        val debug = app.applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE != 0
        val environment = TrustedCallerEnvironment.resolve(app.packageName, debug)
        if (environment != "unavailable") ensureInitialized(environment)
    }

    /** Undo only the DISABLED override written by earlier Flutter versions, once. */
    private fun restoreLegacyHostOverride() {
        val prefs = app.getSharedPreferences("trusted_caller_presentation", Context.MODE_PRIVATE)
        if (prefs.getBoolean("vendor_component_ownership_v1", false)) return
        try {
            val component = android.content.ComponentName(app, "com.weway.chaken.api.impl.PreciseCallReceiver")
            if (app.packageManager.getComponentEnabledSetting(component) ==
                android.content.pm.PackageManager.COMPONENT_ENABLED_STATE_DISABLED) {
                app.packageManager.setComponentEnabledSetting(component,
                    android.content.pm.PackageManager.COMPONENT_ENABLED_STATE_DEFAULT,
                    android.content.pm.PackageManager.DONT_KILL_APP)
            }
            prefs.edit().putBoolean("vendor_component_ownership_v1", true).apply()
        } catch (_: Exception) { /* Retry migration next startup; never rewrite SDK switch. */ }
    }

    internal var initializationFailureCode = "SDK_PREPARE_FAILED"
        private set

    internal fun ensureInitialized(environment: String): Boolean {
        if (initializedEnvironment == environment) return true
        val credentials = TrustedCallerConfiguration.read(environment) ?: run {
            initializationFailureCode = "SDK_CREDENTIALS_MISSING"
            return false
        }
        return try {
            val key = credentials.getValue("appKey")
            Constants.SDK_CODE = "23"
            Constants.VERSION_EXT_CODE = "020002"
            TrustedSdkIdentityInterceptor.install(key)
            HttpClient.getInstance().addCommonParams(HttpParams().apply {
                put("appkey", key)
                put("devicetype", 1)
            })
            HttpClient.getInstance().addCommonHeaders(HttpHeaders().apply {
                put("versioncode", "23")
                put("versionext", "020002")
                put("sdkVersion", "1.5")
                put("sdkType", "2")
                put("extType", "1,2")
            })
            ChakenIncallSdk.getInstance().init(app, key, credentials.getValue("appSecret"))
            initializedEnvironment = environment
            true
        } catch (_: NoClassDefFoundError) {
            initializationFailureCode = "SDK_RUNTIME_MISSING"
            false
        } catch (_: LinkageError) {
            initializationFailureCode = "SDK_RUNTIME_LINKAGE_FAILED"
            false
        } catch (_: Exception) {
            initializationFailureCode = "SDK_INITIALIZATION_EXCEPTION"
            false
        }
    }

    companion object {
        private var instance: TrustedCallerIncomingRuntime? = null
        fun shared(context: Context): TrustedCallerIncomingRuntime = instance ?: TrustedCallerIncomingRuntime(
            context.applicationContext as Application
        ).also { instance = it }
    }
}
