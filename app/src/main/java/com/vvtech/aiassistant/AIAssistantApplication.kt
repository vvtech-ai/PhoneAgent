package com.vvtech.aiassistant

import android.app.Activity
import android.app.Application
import android.content.Context
import android.os.Bundle
import com.vvtech.aiassistant.account.AccountIdentityProvider
import com.vvtech.aiassistant.data.translation.createAndroidTranslationRegionRepository
import com.vvtech.aiassistant.data.translation.DefaultTranslationCallSettingsRepository
import com.vvtech.aiassistant.data.translation.SharedPreferencesTranslationCallSettingsStore
import com.vvtech.aiassistant.data.translation.TranslationCallSettingsRepository
import com.vvtech.aiassistant.domain.translation.TranslationRegionRepository
import com.vvtech.aiassistant.logging.AppCrashHandler
import com.vvtech.aiassistant.logging.AppFileLogger
import com.vvtech.aiassistant.features.assistant.AssistantSpeechPlayerHolder
import com.vvtech.aiassistant.BuildConfig
import com.vvtech.aiassistant.integration.incall.OptionalIncallSdkBridge

class AIAssistantApplication : Application() {
    lateinit var translationRegionRepository: TranslationRegionRepository
        private set
    lateinit var translationCallSettingsRepository: TranslationCallSettingsRepository
        private set

    override fun attachBaseContext(base: Context?) {
        super.attachBaseContext(base)
        OptionalIncallSdkBridge.installProtection(this)
    }

    override fun onCreate() {
        super.onCreate()
        AppFileLogger.initialize(this)
        registerMainLifecycleLogger()
        AppCrashHandler.install()
        AccountIdentityProvider.initialize(this)
        translationRegionRepository = createAndroidTranslationRegionRepository(this)
        translationCallSettingsRepository = DefaultTranslationCallSettingsRepository(
            SharedPreferencesTranslationCallSettingsStore(this)
        )
        AssistantSpeechPlayerHolder.prewarm(this)
        initializeOptionalIncallSdk()
        runCatching {
            Class.forName("com.vvtech.aiassistant.devhook.DevStartupHook")
                .getMethod("invoke", Context::class.java)
                .invoke(null, this)
        }
    }

    private fun initializeOptionalIncallSdk() {
        OptionalIncallSdkBridge.initialize(
            this,
            BuildConfig.OPTIONAL_INCALL_SDK_APP_KEY,
            BuildConfig.OPTIONAL_INCALL_SDK_APP_SECRET
        )
    }

    private fun registerMainLifecycleLogger() {
        registerActivityLifecycleCallbacks(object : ActivityLifecycleCallbacks {
            override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {
                AppFileLogger.lifecycle(activity.lifecycleLogName(), "onCreate saved=${savedInstanceState != null}")
            }

            override fun onActivityStarted(activity: Activity) {
                AppFileLogger.lifecycle(activity.lifecycleLogName(), "onStart")
            }

            override fun onActivityResumed(activity: Activity) {
                AppFileLogger.lifecycle(activity.lifecycleLogName(), "onResume")
            }

            override fun onActivityPaused(activity: Activity) {
                AppFileLogger.lifecycle(activity.lifecycleLogName(), "onPause")
            }

            override fun onActivityStopped(activity: Activity) {
                AppFileLogger.lifecycle(activity.lifecycleLogName(), "onStop")
            }

            override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {
                AppFileLogger.lifecycle(activity.lifecycleLogName(), "onSaveInstanceState")
            }

            override fun onActivityDestroyed(activity: Activity) {
                AppFileLogger.lifecycle(activity.lifecycleLogName(), "onDestroy finishing=${activity.isFinishing}")
            }
        })
    }

    private fun Activity.lifecycleLogName(): String {
        return this::class.java.simpleName.ifBlank { "Activity" }
    }
}
