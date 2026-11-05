package com.vvtech.phone_agent

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Read-only v66 same-package task preferences; never imports other settings. */
class TaskVoicePreferenceChannel(context: Context, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "phone_agent/task_voice_preferences")
    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "readLegacy") { result.notImplemented(); return@setMethodCallHandler }
            if (context.packageName != "com.vvtech.aiassistant") { result.success(null); return@setMethodCallHandler }
            try {
                val speech = context.getSharedPreferences("task_ai_speech_preference", Context.MODE_PRIVATE).all["enabled"]
                val guide = context.getSharedPreferences("voice_guide", Context.MODE_PRIVATE).all["effective_input_completed"]
                result.success(mapOf("speechEnabled" to speech, "guideCompleted" to guide))
            } catch (_: Exception) { result.error("task_voice_preference_failed", "Task preference unavailable", null) }
        }
    }
    fun close() { channel.setMethodCallHandler(null) }
}
