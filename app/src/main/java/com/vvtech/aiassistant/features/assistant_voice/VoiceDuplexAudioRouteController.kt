package com.vvtech.aiassistant.features.assistant_voice

import com.vvtech.aiassistant.features.assistant.*

import android.content.Context
import android.media.AudioManager
import com.vvtech.aiassistant.features.assistant.AssistantViewModel
import com.vvtech.aiassistant.features.assistant.speech.TtsAudioModeController

internal class VoiceDuplexAudioRouteController(
    private val viewModel: AssistantViewModel
) {
    private var voiceConversationRouteActive = false

    fun ensureVoiceConversationAudioRoute(reason: String) {
        if (!voiceConversationRouteActive) {
            voiceConversationRouteActive = true
            viewModel.internalLog("VOICE_DIAG audioMode conversationRoute enter reason=$reason")
        }
        prepareCommunicationAudioMode(reason)
    }

    fun releaseVoiceConversationAudioRoute(reason: String) {
        if (voiceConversationRouteActive) {
            viewModel.internalLog("VOICE_DIAG audioMode conversationRoute release reason=$reason")
        }
        voiceConversationRouteActive = false
        restoreNormalAudioMode(reason = "conversation_release:$reason", force = true)
    }

    fun restoreNormalAudioMode(reason: String = "unspecified", force: Boolean = false) {
        val audioManager = viewModel.appContext.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val beforeMode = audioManager.mode
        val beforeSpeaker = audioManager.isSpeakerphoneOn
        if (!force && voiceConversationRouteActive) {
            viewModel.internalLog(
                "VOICE_DIAG audioMode restoreNormal skipped, voice conversation route active " +
                    "reason=$reason current=${TtsAudioModeController.modeName(audioManager.mode)} speaker=$beforeSpeaker"
            )
            return
        }
        if (TtsAudioModeController.isCommunicationModeActive()) {
            viewModel.internalLog(
                "VOICE_DIAG audioMode restoreNormal skipped, TTS communication mode active " +
                    "reason=$reason current=${TtsAudioModeController.modeName(audioManager.mode)} speaker=$beforeSpeaker"
            )
            return
        }
        if (audioManager.isSpeakerphoneOn) {
            audioManager.isSpeakerphoneOn = false
        }
        if (audioManager.mode != AudioManager.MODE_NORMAL) {
            audioManager.mode = AudioManager.MODE_NORMAL
        }
        viewModel.internalLog(
            "VOICE_DIAG audioMode restoreNormal reason=$reason beforeMode=$beforeMode beforeSpeaker=$beforeSpeaker " +
                "afterMode=${audioManager.mode} afterSpeaker=${audioManager.isSpeakerphoneOn}"
        )
    }

    fun prepareCommunicationAudioMode(reason: String = "unspecified") {
        val audioManager = viewModel.appContext.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val beforeMode = audioManager.mode
        val beforeSpeaker = audioManager.isSpeakerphoneOn
        if (audioManager.mode != AudioManager.MODE_IN_COMMUNICATION) {
            audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
        }
        if (!audioManager.isSpeakerphoneOn) {
            audioManager.isSpeakerphoneOn = true
        }
        viewModel.internalLog(
            "VOICE_DIAG audioMode prepareCommunication reason=$reason beforeMode=$beforeMode beforeSpeaker=$beforeSpeaker " +
                "afterMode=${audioManager.mode} afterSpeaker=${audioManager.isSpeakerphoneOn}"
        )
    }

    fun keepSpeechOutputOnSpeaker() {
        val audioManager = viewModel.appContext.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val beforeMode = audioManager.mode
        val beforeSpeaker = audioManager.isSpeakerphoneOn
        if (audioManager.mode != AudioManager.MODE_IN_COMMUNICATION) {
            audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
        }
        if (!audioManager.isSpeakerphoneOn) {
            audioManager.isSpeakerphoneOn = true
        }
        viewModel.internalLog(
            "VOICE_DIAG audioMode keepSpeaker beforeMode=$beforeMode beforeSpeaker=$beforeSpeaker " +
                "afterMode=${audioManager.mode} afterSpeaker=${audioManager.isSpeakerphoneOn}"
        )
    }
}
