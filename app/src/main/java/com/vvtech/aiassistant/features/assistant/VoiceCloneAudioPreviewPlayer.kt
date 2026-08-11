package com.vvtech.aiassistant.features.assistant

import android.content.Context
import android.media.MediaPlayer

internal class VoiceCloneAudioPreviewPlayer(context: Context) {

    private val appContext = context.applicationContext
    private var mediaPlayer: MediaPlayer? = null
    private var playingPath: String? = null

    fun toggle(filePath: String, onCompletion: () -> Unit): Boolean {
        if (playingPath == filePath) {
            stop()
            return false
        }
        stop()
        val player = MediaPlayer()
        mediaPlayer = player
        playingPath = filePath
        player.setDataSource(appContext, android.net.Uri.fromFile(java.io.File(filePath)))
        player.setOnCompletionListener {
            stop()
            onCompletion()
        }
        player.prepare()
        player.start()
        return true
    }

    fun stop() {
        mediaPlayer?.runCatching {
            if (isPlaying) stop()
        }
        mediaPlayer?.release()
        mediaPlayer = null
        playingPath = null
    }

    fun currentPath(): String? = playingPath
}
