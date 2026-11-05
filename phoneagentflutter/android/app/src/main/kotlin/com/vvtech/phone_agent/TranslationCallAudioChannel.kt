package com.vvtech.phone_agent

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

class TranslationCallAudioChannel(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "phone_agent/translation_call_audio")
    private var foreground = true
    private var owned: String? = null
    init {
        channel.setMethodCallHandler { call, result ->
            val id = call.argument<String>("callAudioId")
            if (id == null || !id.matches(Regex("[a-f0-9]{32}"))) {
                result.error("call_audio_invalid", "Call audio unavailable", null)
            } else when (call.method) {
                "acquire" -> {
                    if (!foreground || owned != null || TranslationCallAudioOwner.id != null ||
                        activity.checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
                        result.error("call_audio_unavailable", "Foreground microphone admission required", null)
                    } else {
                        owned = id
                        TranslationCallAudioOwner.id = id
                        TranslationCallAudioOwner.ready = { ok ->
                            if (ok) result.success(true) else result.error("call_audio_unavailable", "Call audio service unavailable", null)
                        }
                        try {
                            val intent = Intent(activity, TranslationCallAudioService::class.java).putExtra("callAudioId", id)
                            if (Build.VERSION.SDK_INT >= 26) activity.startForegroundService(intent) else activity.startService(intent)
                            Handler(Looper.getMainLooper()).postDelayed({
                                if (TranslationCallAudioOwner.id == id && !TranslationCallAudioOwner.active) {
                                    TranslationCallAudioOwner.clear()
                                    activity.stopService(Intent(activity, TranslationCallAudioService::class.java))
                                    if (owned == id) owned = null
                                }
                            }, 6000)
                        } catch (_: Exception) { TranslationCallAudioOwner.clear(); owned = null }
                    }
                }
                "release" -> {
                    if (owned == id) {
                        TranslationCallAudioOwner.stopNow?.invoke()
                        if (TranslationCallAudioOwner.id == id) TranslationCallAudioOwner.clear()
                        activity.stopService(Intent(activity, TranslationCallAudioService::class.java))
                        owned = null
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
    fun setForeground(value: Boolean) { foreground = value }
    fun close() {
        channel.setMethodCallHandler(null)
        if (owned != null && owned == TranslationCallAudioOwner.id) {
            TranslationCallAudioOwner.stopNow?.invoke()
            TranslationCallAudioOwner.clear()
            activity.stopService(Intent(activity, TranslationCallAudioService::class.java))
        }
        owned = null
    }
}
