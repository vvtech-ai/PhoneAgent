package com.vvtech.aiassistant.features.assistant_voice_clone.enrollment

import android.app.Activity
import android.content.Context
import com.vvtech.aiassistant.features.assistant_voice_clone.logVoiceCloneRuntime
import java.lang.reflect.Method
import java.lang.reflect.Proxy
import java.util.HashMap

internal data class IdProSdkResult(val code: Int, val reason: String)

internal interface IdProSdkAdapter {
    fun prepare(context: Context): Result<String>
    fun verify(activity: Activity, certifyId: String, callback: (IdProSdkResult) -> Unit): Result<Unit>
    fun abortActiveVerification()
    fun clearPreparedSession()
}

internal class AliyunIdProSdkAdapter : IdProSdkAdapter {
    private val sessionLock = Any()
    private var activeFacade: Any? = null
    @Volatile
    private var preparedMetaInfo: String? = null
    @Volatile
    private var preparationGeneration: Long = 0

    override fun prepare(context: Context): Result<String> = runCatching {
        preparedMetaInfo?.takeIf(String::isNotBlank)?.let { return@runCatching it }
        val generation = preparationGeneration
        val facade = Class.forName(FACADE_CLASS)
        facade.getMethod("install", Context::class.java).invoke(null, context.applicationContext)
        val value = facade.getMethod("getMetaInfos", Context::class.java)
            .invoke(null, context.applicationContext) as? String
        require(!value.isNullOrBlank()) { "设备认证信息获取失败" }
        synchronized(sessionLock) {
            if (generation == preparationGeneration) {
                preparedMetaInfo = value
            }
        }
        value
    }

    override fun verify(
        activity: Activity,
        certifyId: String,
        callback: (IdProSdkResult) -> Unit
    ): Result<Unit> = runCatching {
        require(certifyId.isNotBlank()) { "CertifyId不能为空" }
        check(MfvcVerificationSession.tryStart()) { "认证正在进行中，请勿重复操作。" }
        var facade: Any? = null
        try {
            val builderClass = Class.forName(BUILDER_CLASS)
            val callbackClass = Class.forName(CALLBACK_CLASS)
            facade = requireNotNull(
                resolveCreateMethod(builderClass).invoke(null, activity)
            ) { "阿里云认证组件初始化失败" }
            synchronized(sessionLock) {
                activeFacade = facade
            }
            applyUiTheme(facade)
            val callbackProxy = Proxy.newProxyInstance(
                callbackClass.classLoader,
                arrayOf(callbackClass)
            ) { _, method, args ->
                if (method.name == "response") {
                    val response = args?.firstOrNull()
                    try {
                        callback(
                            IdProSdkResult(
                                readInt(response, "code"),
                                readString(response, "reason")
                            )
                        )
                    } finally {
                        finishSession(facade)
                    }
                    true
                } else null
            }
            facade.javaClass.getMethod(
                "verify",
                String::class.java,
                Boolean::class.javaPrimitiveType,
                HashMap::class.java,
                callbackClass
            ).invoke(facade, certifyId, true, buildExtParams(), callbackProxy)
        } catch (throwable: Throwable) {
            finishSession(facade)
            throw throwable
        }
    }

    override fun abortActiveVerification() {
        val facade = synchronized(sessionLock) {
            activeFacade.also { activeFacade = null }
        }
        if (facade != null) {
            releaseFacade(facade)
        }
        MfvcVerificationSession.finish()
    }

    override fun clearPreparedSession() {
        synchronized(sessionLock) {
            preparationGeneration++
            preparedMetaInfo = null
        }
    }

    private fun finishSession(facade: Any?) {
        val shouldRelease = synchronized(sessionLock) {
            when {
                facade == null && activeFacade == null -> true
                activeFacade === facade -> {
                    activeFacade = null
                    true
                }
                else -> false
            }
        }
        if (!shouldRelease) return
        if (facade != null) {
            releaseFacade(facade)
        }
        MfvcVerificationSession.finish()
    }

    private fun releaseFacade(facade: Any) {
        runCatching {
            facade.javaClass.getMethod("release").invoke(facade)
        }.onFailure { throwable ->
            logVoiceCloneRuntime(
                eventType = "VOICE_CLONE_SDK_RELEASE_FAILED",
                result = "failed",
                reason = "sdk_release_failed",
                throwable = throwable,
                provider = PROVIDER
            )
        }
    }

    private fun applyUiTheme(facade: Any) {
        runCatching {
            facade.javaClass.getMethod(
                "setCustomUIConfig",
                Int::class.javaPrimitiveType,
                String::class.java
            ).invoke(
                facade,
                AliyunIdProUiTheme.CONFIG_TYPE_JSON,
                AliyunIdProUiTheme.json
            )?.toString().orEmpty()
        }.onSuccess { validationError ->
            logVoiceCloneRuntime(
                eventType = "VOICE_CLONE_SDK_UI_THEME_CONFIGURED",
                result = if (validationError.isBlank()) "accepted" else "fallback",
                reason = validationError.takeIf(String::isNotBlank)
                    ?.let { "sdk_rejected_config" },
                provider = PROVIDER,
                attributes = mapOf(
                    "themeRevision" to THEME_REVISION,
                    "videoEvidenceRequested" to "false"
                )
            )
        }.onFailure { throwable ->
            logVoiceCloneRuntime(
                eventType = "VOICE_CLONE_SDK_UI_THEME_CONFIGURED",
                result = "fallback",
                reason = "sdk_api_unavailable",
                throwable = throwable,
                provider = PROVIDER
            )
        }
    }

    private fun buildExtParams(): HashMap<String, String> = hashMapOf(
        VIDEO_EVIDENCE_EXT_PARAM_KEY to "false",
        FULLSCREEN_EXT_PARAM_KEY to "false",
        SCREEN_ORIENTATION_EXT_PARAM_KEY to SCREEN_ORIENTATION_PORTRAIT
    )

    private fun resolveCreateMethod(builderClass: Class<*>): Method =
        builderClass.methods.firstOrNull { method ->
            method.name == "create" && method.parameterCount == 1 &&
                Context::class.java.isAssignableFrom(method.parameterTypes[0])
        } ?: builderClass.getMethod("create", Activity::class.java)

    private fun readInt(target: Any?, name: String): Int = runCatching {
        target?.javaClass?.getField(name)?.getInt(target) ?: -1
    }.getOrElse {
        runCatching { (target?.javaClass?.getMethod("get${name.replaceFirstChar { it.uppercase() }}")
            ?.invoke(target) as? Number)?.toInt() ?: -1 }.getOrDefault(-1)
    }

    private fun readString(target: Any?, name: String): String = runCatching {
        target?.javaClass?.getField(name)?.get(target)?.toString().orEmpty()
    }.getOrElse {
        runCatching { target?.javaClass?.getMethod("get${name.replaceFirstChar { it.uppercase() }}")
            ?.invoke(target)?.toString().orEmpty() }.getOrDefault("")
    }

    private companion object {
        const val FACADE_CLASS = "com.alipay.face.api.ZIMFacade"
        const val BUILDER_CLASS = "com.alipay.face.api.ZIMFacadeBuilder"
        const val CALLBACK_CLASS = "com.alipay.face.api.ZIMCallback"
        const val VIDEO_EVIDENCE_EXT_PARAM_KEY = "ext_params_key_use_video"
        const val FULLSCREEN_EXT_PARAM_KEY = "ext_params_key_open_fullscreen"
        const val SCREEN_ORIENTATION_EXT_PARAM_KEY = "ext_params_key_screen_orientation"
        const val SCREEN_ORIENTATION_PORTRAIT = "ext_params_val_screen_port"
        const val THEME_REVISION = "blue-v2"
        const val PROVIDER = "aliyun_mfvc"
    }
}
