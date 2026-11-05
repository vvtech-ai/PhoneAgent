package com.vvtech.phone_agent

import android.media.AudioManager
import android.media.AudioTrack
import android.os.Build
import android.util.Log

/** Safe device facts only: no account, text, PCM, request ID or SDK material. */
internal object PcmOutputDiagnostics {
    fun record(track: AudioTrack, manager: AudioManager, stage: String, frames: Long = 0) {
        runCatching {
            val device = if (Build.VERSION.SDK_INT >= 23) track.routedDevice?.type else null
            val muted = if (Build.VERSION.SDK_INT >= 23) manager.isStreamMute(AudioManager.STREAM_MUSIC) else false
            Log.i("PcmOutput", "stage=$stage deviceType=$device stream=${AudioManager.STREAM_MUSIC} " +
                "volume=${manager.getStreamVolume(AudioManager.STREAM_MUSIC)} muted=$muted " +
                "mode=${manager.mode} playState=${track.playState} playedFrames=$frames")
        }.onFailure { Log.w("PcmOutput", "stage=diagnostic_unavailable") }
    }
}
