package com.vvtech.aiassistant.features.translation_call.backend

import android.content.Context
import android.media.AudioManager
import io.livekit.android.LiveKit
import io.livekit.android.events.RoomEvent
import io.livekit.android.events.collect
import io.livekit.android.room.Room
import java.util.concurrent.atomic.AtomicBoolean
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

internal interface BackendLiveKitTransport {
    fun connect(connection: BackendLiveKitConnection, listener: Listener)
    fun setMuted(muted: Boolean)
    fun setSpeakerEnabled(enabled: Boolean)
    fun close()

    interface Listener {
        fun onRoomReady()
        fun onControlMessage(message: BackendRealtimeMessage)
        fun onLinkAvailable(available: Boolean)
        fun onError(message: String)
        fun onDisconnected()
    }
}

internal class BackendLiveKitAudioClient(
    context: Context
) : BackendLiveKitTransport {
    private val appContext = context.applicationContext
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val closed = AtomicBoolean()
    private var room: Room? = null
    private var listener: BackendLiveKitTransport.Listener? = null
    @Volatile private var muted = false
    @Volatile private var speakerEnabled = true

    override fun connect(
        connection: BackendLiveKitConnection,
        listener: BackendLiveKitTransport.Listener
    ) {
        this.listener = listener
        scope.launch {
            try {
                val liveRoom = LiveKit.create(appContext)
                room = liveRoom
                collectEvents(liveRoom)
                configureAudioRoute(speakerEnabled)
                liveRoom.connect(connection.url, connection.token)
                liveRoom.localParticipant.setMicrophoneEnabled(!muted)
                if (!closed.get()) listener.onRoomReady()
            } catch (error: Exception) {
                if (!closed.get()) {
                    listener.onError(error.message ?: "LiveKit 连接失败")
                }
            }
        }
    }

    override fun setMuted(muted: Boolean) {
        this.muted = muted
        scope.launch {
            runCatching { room?.localParticipant?.setMicrophoneEnabled(!muted) }
        }
    }

    override fun setSpeakerEnabled(enabled: Boolean) {
        speakerEnabled = enabled
        configureAudioRoute(enabled)
    }

    override fun close() {
        if (!closed.compareAndSet(false, true)) return
        runCatching { room?.disconnect() }
        room = null
        listener = null
        releaseAudioRoute()
        scope.cancel()
    }

    private fun collectEvents(liveRoom: Room) {
        scope.launch {
            liveRoom.events.collect { event ->
                when (event) {
                    is RoomEvent.DataReceived -> {
                        if (!event.topic.isNullOrBlank() && event.topic != ControlTopic) {
                            return@collect
                        }
                        runCatching {
                            BackendRealtimeProtocol.parseText(
                                event.data.toString(Charsets.UTF_8)
                            )
                        }.onSuccess { listener?.onControlMessage(it) }
                            .onFailure {
                                listener?.onError(it.message ?: "LiveKit 控制消息解析失败")
                            }
                    }
                    is RoomEvent.Reconnecting -> listener?.onLinkAvailable(false)
                    is RoomEvent.Reconnected -> listener?.onLinkAvailable(true)
                    is RoomEvent.Disconnected -> if (!closed.get()) {
                        listener?.onDisconnected()
                    }
                    is RoomEvent.FailedToConnect -> if (!closed.get()) {
                        listener?.onError(event.error.message ?: "LiveKit 入会失败")
                    }
                    else -> Unit
                }
            }
        }
    }

    private fun configureAudioRoute(enabled: Boolean) {
        val audioManager = appContext.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
            ?: return
        audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
        audioManager.isSpeakerphoneOn = enabled
    }

    private fun releaseAudioRoute() {
        val audioManager = appContext.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
            ?: return
        audioManager.mode = AudioManager.MODE_NORMAL
        audioManager.isSpeakerphoneOn = false
    }

    private companion object {
        const val ControlTopic = "translation-call.control"
    }
}
