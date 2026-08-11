package com.vvtech.aiassistant.features.assistant_voice_clone

import android.os.SystemClock
import com.vvtech.aiassistant.features.assistant_voice_clone.face.FacePresencePolicy
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

internal class VoiceCloneRecordingWatchdog(
    private val scope: CoroutineScope,
    private val nowMs: () -> Long = SystemClock::elapsedRealtime
) {
    private var job: Job? = null

    fun start(onTick: (Long) -> Unit) {
        stop()
        job = scope.launch {
            while (true) {
                delay(FacePresencePolicy.SAMPLE_INTERVAL_MS)
                onTick(nowMs())
            }
        }
    }

    fun stop() {
        job?.cancel()
        job = null
    }
}
