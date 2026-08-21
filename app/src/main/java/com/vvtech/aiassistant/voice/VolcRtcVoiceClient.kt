package com.vvtech.aiassistant.voice

import com.vvtech.aiassistant.logging.AppFileLogger

import android.content.Context
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import com.ss.bytertc.engine.RTCEngine
import com.ss.bytertc.engine.RTCRoom
import com.ss.bytertc.engine.RTCRoomConfig
import com.ss.bytertc.engine.UserInfo
import com.ss.bytertc.engine.data.EngineConfig
import com.ss.bytertc.engine.handler.IRTCEngineEventHandler
import com.ss.bytertc.engine.handler.IRTCRoomEventHandler
import com.ss.bytertc.engine.type.ChannelProfile
import com.ss.bytertc.engine.type.SubtitleConfig
import com.ss.bytertc.engine.type.SubtitleErrorCode
import com.ss.bytertc.engine.type.SubtitleMessage
import com.ss.bytertc.engine.type.SubtitleMode
import com.ss.bytertc.engine.type.SubtitleState

/**
 * RTC audio room wrapper for homepage realtime voice.
 *
 * For the realtime assistant flow, RTC owns the microphone/audio route again
 * so the user and AI can stay inside a single low-latency voice session.
 * The legacy homepage transcription tunnel remains only as a fallback path.
 */
class VolcRtcVoiceClient(
    private val appContext: Context
) {

    private var rtcEngine: RTCEngine? = null
    private var rtcRoom: RTCRoom? = null
    private var eventCallback: ((VoiceRuntimeEvent) -> Unit)? = null
    private var emittedConnected = false
    private var subtitleStarted = false
    private var localUserId: String? = null

    private val rtcEngineEventHandler = object : IRTCEngineEventHandler() {
        override fun onWarning(warn: Int) {
            emit(VoiceRuntimeEvent.Status(currentAppText("实时语音警告：$warn", "Realtime voice warning: $warn")))
        }

        override fun onError(err: Int) {
            emit(VoiceRuntimeEvent.Error(currentAppText("实时语音引擎错误：$err", "Realtime voice engine error: $err")))
        }
    }

    private val rtcRoomEventHandler = object : IRTCRoomEventHandler() {
        override fun onRoomStateChanged(roomId: String?, uid: String?, state: Int, extraInfo: String?) {
            AppFileLogger.d(TAG, "onRoomStateChanged state=$state roomId=$roomId uid=$uid extra=$extraInfo")
            emit(VoiceRuntimeEvent.Status(currentAppText("语音房间状态：$state", "Voice room state: $state")))
            if (state == 0 && !emittedConnected) {
                emittedConnected = true
                emit(VoiceRuntimeEvent.Connected(currentAppText("语音房间已连接", "Voice room connected")))
            }
            if (state == 0) {
                startSubtitleIfNeeded()
            }
        }

        override fun onUserJoined(userInfo: UserInfo?) {
            AppFileLogger.d(TAG, "onUserJoined uid=${userInfo?.uid}")
            if (!emittedConnected) {
                emittedConnected = true
                emit(VoiceRuntimeEvent.Connected(currentAppText("语音房间已接通", "Voice room connected")))
            } else {
                val remoteUser = userInfo?.uid ?: currentAppText("远端用户", "Remote user")
                emit(VoiceRuntimeEvent.Status(currentAppText(
                    "${remoteUser} 已进入语音房间",
                    "$remoteUser joined the voice room"
                )))
            }
            startSubtitleIfNeeded()
        }

        override fun onUserLeave(uid: String?, reason: Int) {
            AppFileLogger.d(TAG, "onUserLeave uid=$uid reason=$reason")
            val remoteUser = uid ?: currentAppText("远端用户", "Remote user")
            emit(VoiceRuntimeEvent.Status(currentAppText(
                "${remoteUser} 已离开语音房间",
                "$remoteUser left the voice room"
            )))
        }

        override fun onTokenWillExpire() {
            emit(VoiceRuntimeEvent.Error(currentAppText(
                "实时语音 token 即将过期，请重新连接",
                "Realtime voice token is about to expire. Please reconnect"
            )))
        }

        override fun onSubtitleStateChanged(
            state: SubtitleState?,
            errorCode: SubtitleErrorCode?,
            errorMessage: String?
        ) {
            AppFileLogger.d(TAG, "onSubtitleStateChanged state=$state errorCode=$errorCode errorMessage=$errorMessage")
            when (state) {
                SubtitleState.SUBTITLE_STATE_STARTED -> {
                    subtitleStarted = true
                    emit(VoiceRuntimeEvent.Status(currentAppText("实时字幕已启动", "Realtime captions started")))
                }

                SubtitleState.SUBTITLE_STATE_ERROR -> {
                    emit(
                        VoiceRuntimeEvent.Status(
                            buildString {
                                append(currentAppText("实时字幕启动失败", "Failed to start realtime captions"))
                                if (!errorMessage.isNullOrBlank()) {
                                    append(": ").append(errorMessage)
                                } else if (errorCode != null) {
                                    append(": ").append(errorCode.name)
                                }
                            }
                        )
                    )
                }

                SubtitleState.SUBTITLE_STATE_STOPED -> {
                    subtitleStarted = false
                }

                else -> Unit
            }
        }

        override fun onSubtitleMessageReceived(messages: Array<out SubtitleMessage>?) {
            messages.orEmpty().forEach { message ->
                val text = message.text?.trim().orEmpty()
                if (text.isBlank()) {
                    return@forEach
                }
                AppFileLogger.d(
                    TAG,
                    "subtitle userId=${message.userId} local=$localUserId definite=${message.definite} text=$text"
                )
                val speaker = when (message.userId) {
                    null, "" -> VoiceTranscriptSpeaker.Unknown
                    localUserId -> VoiceTranscriptSpeaker.LocalUser
                    else -> VoiceTranscriptSpeaker.RemoteAssistant
                }
                emit(
                    VoiceRuntimeEvent.Transcript(
                        speaker = speaker,
                        text = text,
                        definite = message.definite
                    )
                )
            }
        }
    }

    fun start(
        config: VoiceRuntimeConfig,
        onEvent: (VoiceRuntimeEvent) -> Unit
    ) {
        stopInternal(notifyStopped = false)
        eventCallback = onEvent
        emittedConnected = false
        subtitleStarted = false
        localUserId = config.userId
        emit(VoiceRuntimeEvent.Connecting("正在连接实时语音..."))

        val engineConfig = EngineConfig().apply {
            context = appContext
            appID = config.appId
        }
        rtcEngine = RTCEngine.createRTCEngine(engineConfig, rtcEngineEventHandler)
        rtcEngine?.startAudioCapture()

        rtcRoom = rtcEngine?.createRTCRoom(config.roomId)?.also { room ->
            room.setRTCRoomEventHandler(rtcRoomEventHandler)
            val roomConfig = RTCRoomConfig(
                ChannelProfile.CHANNEL_PROFILE_CHAT_ROOM,
                null,
                true,
                false,
                true,
                false
            )
            room.joinRoom(
                config.token,
                UserInfo(config.userId, ""),
                true,
                roomConfig
            )
            room.publishStreamAudio(true)
            startSubtitleIfNeeded()
        }
    }

    fun stop() {
        stopInternal(notifyStopped = true)
    }

    fun release() {
        stopInternal(notifyStopped = false)
        eventCallback = null
    }

    private fun stopInternal(notifyStopped: Boolean) {
        runCatching { rtcRoom?.publishStreamAudio(false) }
        runCatching { rtcRoom?.stopSubtitle() }
        runCatching { rtcRoom?.leaveRoom() }
        runCatching { rtcRoom?.destroy() }
        rtcRoom = null
        runCatching { rtcEngine?.stopAudioCapture() }
        rtcEngine = null
        runCatching { RTCEngine.destroyRTCEngine() }
        subtitleStarted = false
        localUserId = null
        if (notifyStopped) {
            emit(VoiceRuntimeEvent.Stopped)
        }
    }

    private fun startSubtitleIfNeeded() {
        if (subtitleStarted) return
        val room = rtcRoom ?: return
        val result = room.startSubtitle(
            SubtitleConfig(
                SubtitleMode.SUBTITLE_MODE_RECOGINTE,
                "zh-CN"
            )
        )
        if (result == 0) {
            subtitleStarted = true
        } else {
            emit(VoiceRuntimeEvent.Status(currentAppText(
                "实时字幕未启动成功（$result）",
                "Realtime captions did not start successfully ($result)"
            )))
        }
    }

    private fun emit(event: VoiceRuntimeEvent) {
        eventCallback?.invoke(event)
    }

    private companion object {
        const val TAG = "VolcRtcVoiceClient"
    }
}
