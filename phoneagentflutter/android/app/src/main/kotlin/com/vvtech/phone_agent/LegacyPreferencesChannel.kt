package com.vvtech.phone_agent

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/** Same-package, read-only whitelist. No paths, credentials or permission state. */
class LegacyPreferencesChannel(context: Context, messenger: BinaryMessenger) {
    private val app = context.applicationContext
    private val channel = MethodChannel(messenger, "com.vvtech.phone_agent/legacy_preferences")
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    @Volatile private var closed = false

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "read") {
                result.notImplemented()
            } else {
                worker.execute {
                    try {
                        val value = if (app.packageName != "com.vvtech.aiassistant") null else snapshot()
                        main.post { if (!closed) result.success(value) }
                    } catch (_: Exception) {
                        main.post { if (!closed) result.error(
                            "LEGACY_PREFERENCES_UNAVAILABLE", "Local upgrade data unavailable", null
                        ) }
                    }
                }
            }
        }
    }

    private fun snapshot(): Map<String, Any?> {
        val settings = app.getSharedPreferences("translation_call_settings", Context.MODE_PRIVATE)
        val dial = app.getSharedPreferences("index9_native_screen", Context.MODE_PRIVATE)
        val region = app.getSharedPreferences("translation_region_state", Context.MODE_PRIVATE)
        val translation = mutableMapOf<String, Any?>()
        val original = mutableMapOf<String, Any?>()
        val location = mutableMapOf<String, Any?>()
        val regionValues = region.all
        if (regionValues.containsKey("trusted_country_iso")) {
            location["countryIso"] = regionValues["trusted_country_iso"]
        }
        if (regionValues.containsKey("trusted_country_sampled_at_ms")) {
            location["sampledAtMs"] = regionValues["trusted_country_sampled_at_ms"]
        }
        val dialKeys = mapOf(
            "enabled" to "dial_translation_enabled",
            "prompt" to "dial_prompt_before_translation",
            "caller" to "dial_translation_language_mine",
            "peer" to "dial_translation_language_other",
            "normalCountry" to "dial_country_normal",
            "translationCountry" to "dial_country_translation"
        )
        val modelKeys = mapOf(
            "provider" to "translation_overseas_provider",
            "region" to "translation_service_region",
            "forceBackend" to "translation_force_backend_webrtc_for_testing"
        )
        val audioKeys = mapOf(
            "enabled" to "translation_play_original_audio",
            "gain" to "translation_original_audio_gain_percent",
            "volume" to "translation_original_audio_volume_percent"
        )
        val dialValues = dial.all
        val settingsValues = settings.all
        for ((target, source) in dialKeys) if (dialValues.containsKey(source)) translation[target] = dialValues[source]
        for ((target, source) in modelKeys) if (settingsValues.containsKey(source)) translation[target] = settingsValues[source]
        for ((target, source) in audioKeys) if (settingsValues.containsKey(source)) original[target] = settingsValues[source]
        return mapOf(
            "version" to 1,
            "translation" to translation.takeIf { it.isNotEmpty() },
            "originalAudio" to original.takeIf { it.isNotEmpty() },
            "location" to location.takeIf { it.isNotEmpty() },
            "voice" to if (dialValues.containsKey("voice_language_code"))
                mapOf("language" to dialValues["voice_language_code"]) else null,
            "initialization" to if (dialValues.containsKey("identity_initialization_skipped"))
                mapOf("skipped" to dialValues["identity_initialization_skipped"]) else null
        )
    }

    fun close() {
        closed = true
        channel.setMethodCallHandler(null)
        worker.shutdown()
    }
}
