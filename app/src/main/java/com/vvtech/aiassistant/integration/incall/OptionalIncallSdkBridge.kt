package com.vvtech.aiassistant.integration.incall

import android.app.Application
import android.content.Context
import android.content.Intent
import com.vvtech.aiassistant.logging.AppFileLogger

/**
 * Reflection boundary for the bundled first-party hardened in-call SDK.
 *
 * Reflection keeps startup resilient when a downstream build intentionally omits
 * the SDK. Service initialization still requires authorized client parameters
 * injected through local Gradle properties; those values are never committed.
 */
internal object OptionalIncallSdkBridge {
    private const val Tag = "OptionalIncallSdk"
    private const val SdkClass = "com.weway.chaken.incallsdk.ChakenIncallSdk"
    private const val ProtectionHelperClass = "com.secneo.weway.Helper"
    private const val SettingsActivityClass = "com.weway.chaken.incallsdk.SettingActivity"

    fun installProtection(context: Context) {
        runCatching {
            val application = (context.applicationContext as? Application)
                ?: (context as? Application)
                ?: error("Trusted-call protection requires an Application context")
            Class.forName(ProtectionHelperClass)
                .getMethod("install", Application::class.java)
                .invoke(null, application)
        }.onFailure { logUnavailable("protection_install_skipped", it) }
    }

    fun initialize(context: Context, appKey: String, appSecret: String): Boolean {
        if (appKey.isBlank() || appSecret.isBlank()) {
            AppFileLogger.i(Tag, "Optional in-call SDK initialization skipped: credentials not configured")
            return false
        }
        return runCatching {
            sdkInstance().javaClass
                .getMethod("init", Context::class.java, String::class.java, String::class.java)
                .invoke(sdkInstance(), context.applicationContext, appKey, appSecret)
            true
        }.onFailure { logUnavailable("sdk_init_failed", it) }.getOrDefault(false)
    }

    fun openMainUi(context: Context): Boolean = runCatching {
        sdkInstance().javaClass
            .getMethod("openIncallUi", Context::class.java)
            .invoke(sdkInstance(), context)
        true
    }.onFailure { logUnavailable("sdk_ui_unavailable", it) }.getOrDefault(false)

    fun openSettings(context: Context): Boolean = runCatching {
        val intent = Intent().setClassName(context.packageName, SettingsActivityClass)
        if (context !is android.app.Activity) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
        true
    }.recoverCatching {
        check(openMainUi(context)) { "Optional in-call SDK is not installed" }
        true
    }.onFailure { logUnavailable("sdk_settings_unavailable", it) }.getOrDefault(false)

    private fun sdkInstance(): Any {
        val sdk = Class.forName(SdkClass)
        return requireNotNull(sdk.getMethod("getInstance").invoke(null))
    }

    private fun logUnavailable(event: String, throwable: Throwable) {
        AppFileLogger.w(
            Tag,
            "$event type=${throwable.javaClass.simpleName} message=${throwable.message.orEmpty()}"
        )
    }
}
