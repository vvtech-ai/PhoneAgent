package com.vvtech.aiassistant.features.assistant_status

import com.vvtech.aiassistant.features.assistant.VoiceLanguage

internal class AssistantLocalizedStatusTextProvider(
    private val currentVoiceLanguage: () -> VoiceLanguage
) {
    fun taskReadyStatus(): String = when (currentVoiceLanguage()) {
        VoiceLanguage.English -> "Task details are ready. Please confirm to continue."
        VoiceLanguage.Japanese -> "依頼内容を整理しました。確認して続けてください。"
        VoiceLanguage.Chinese -> "任务信息已经整理好了，确认后继续"
    }

    fun detailLabel(): String = when (currentVoiceLanguage()) {
        VoiceLanguage.English -> "Extra details"
        VoiceLanguage.Japanese -> "追加条件"
        VoiceLanguage.Chinese -> "补充细节"
    }

    fun contactLabel(): String = when (currentVoiceLanguage()) {
        VoiceLanguage.English -> "Booking contact"
        VoiceLanguage.Japanese -> "予約者情報"
        VoiceLanguage.Chinese -> "预留信息"
    }

    fun confirmingSelectionOptionStatus(title: String): String = when (currentVoiceLanguage()) {
        VoiceLanguage.English -> "Confirming $title..."
        VoiceLanguage.Japanese -> "$title を確認しています..."
        VoiceLanguage.Chinese -> "正在确认$title..."
    }

    fun selectionOptionConfirmFailureError(): String = when (currentVoiceLanguage()) {
        VoiceLanguage.English -> "Failed to confirm this option"
        VoiceLanguage.Japanese -> "候補の確認に失敗しました"
        VoiceLanguage.Chinese -> "选项确认失败"
    }

    fun selectionOptionConfirmFailureStatus(): String = when (currentVoiceLanguage()) {
        VoiceLanguage.English -> "Confirmation failed. Please try again."
        VoiceLanguage.Japanese -> "確認に失敗しました。もう一度お試しください。"
        VoiceLanguage.Chinese -> "确认失败，请再试一次"
    }

    fun listeningStatus(): String = when (currentVoiceLanguage()) {
        VoiceLanguage.English -> "Listening..."
        VoiceLanguage.Japanese -> "聞いています..."
        VoiceLanguage.Chinese -> "正在听你说..."
    }

    fun aiSpeakingStatus(): String = when (currentVoiceLanguage()) {
        VoiceLanguage.English -> "AI is speaking..."
        VoiceLanguage.Japanese -> "AI が話しています..."
        VoiceLanguage.Chinese -> "AI 正在说话..."
    }

    fun startingVoiceStatus(): String = when (currentVoiceLanguage()) {
        VoiceLanguage.English -> "Starting voice..."
        VoiceLanguage.Japanese -> "音声を開始しています..."
        VoiceLanguage.Chinese -> "正在启动语音..."
    }

    fun connectingVoiceStatus(): String = when (currentVoiceLanguage()) {
        VoiceLanguage.English -> "Connecting voice..."
        VoiceLanguage.Japanese -> "音声に接続しています..."
        VoiceLanguage.Chinese -> "正在连接语音..."
    }

    fun reconnectingVoiceStatus(): String = when (currentVoiceLanguage()) {
        VoiceLanguage.English -> "Reconnecting voice..."
        VoiceLanguage.Japanese -> "音声に再接続しています..."
        VoiceLanguage.Chinese -> "正在重新连接语音..."
    }

    fun realtimeTranscriptionConnectingStatus(): String = when (currentVoiceLanguage()) {
        VoiceLanguage.English -> "Connecting transcription..."
        VoiceLanguage.Japanese -> "音声認識に接続しています..."
        VoiceLanguage.Chinese -> "正在连接实时转写..."
    }

    fun switchingSceneStatus(): String = when (currentVoiceLanguage()) {
        VoiceLanguage.English -> "Switching mode..."
        VoiceLanguage.Japanese -> "モードを切り替えています..."
        VoiceLanguage.Chinese -> "正在切换场景..."
    }

    fun speechFallbackSwitchingStatus(): String = when (currentVoiceLanguage()) {
        VoiceLanguage.English -> "The transcription channel is unavailable. Switching recognition mode..."
        VoiceLanguage.Japanese -> "音声認識チャネルに問題があります。別の認識方式に切り替えています..."
        VoiceLanguage.Chinese -> "实时转写通道异常，正在切到系统识别..."
    }

    fun realtimeFallbackStatus(): String = when (currentVoiceLanguage()) {
        VoiceLanguage.English -> "Live voice was interrupted. Switching to transcription..."
        VoiceLanguage.Japanese -> "リアルタイム音声が中断されました。音声認識に切り替えています..."
        VoiceLanguage.Chinese -> "语音会话中断，正在切到实时转写..."
    }

    fun voiceUnavailableStatus(): String = when (currentVoiceLanguage()) {
        VoiceLanguage.English -> "Voice is unavailable. Tap the microphone again."
        VoiceLanguage.Japanese -> "音声が一時的に利用できません。もう一度マイクをタップしてください。"
        VoiceLanguage.Chinese -> "语音暂时不可用，请重新点击麦克风"
    }

    fun voiceInterruptedStatus(): String = when (currentVoiceLanguage()) {
        VoiceLanguage.English -> "Voice was interrupted. Tap the microphone again to continue."
        VoiceLanguage.Japanese -> "音声が中断されました。続けるにはもう一度マイクをタップしてください。"
        VoiceLanguage.Chinese -> "语音会话中断，请重新点击麦克风继续"
    }

    fun tapMicToContinueStatus(): String = when (currentVoiceLanguage()) {
        VoiceLanguage.English -> "Tap the microphone again to continue."
        VoiceLanguage.Japanese -> "続けるにはもう一度マイクをタップしてください。"
        VoiceLanguage.Chinese -> "你可以再点一下麦克风继续说"
    }

    fun pausedTapToContinueStatus(): String = when (currentVoiceLanguage()) {
        VoiceLanguage.English -> "Paused. Tap to continue speaking."
        VoiceLanguage.Japanese -> "一時停止中。タップして話を続けてください。"
        VoiceLanguage.Chinese -> "已暂停，点击继续说话"
    }

    fun noValidSpeechStatus(): String = when (currentVoiceLanguage()) {
        VoiceLanguage.English -> "Didn't hear anything. Please try again."
        VoiceLanguage.Japanese -> "聞き取れませんでした。もう一度お試しください。"
        VoiceLanguage.Chinese -> "没听到声音，请再试一次"
    }

    fun confirmingDetailsStatus(sceneType: String?): String = when (currentVoiceLanguage()) {
        VoiceLanguage.English -> if (sceneType == "GENERAL") "AI is replying" else "Confirming details"
        VoiceLanguage.Japanese -> if (sceneType == "GENERAL") "AI が返答しています" else "内容を確認しています"
        VoiceLanguage.Chinese -> if (sceneType == "GENERAL") "AI在回复" else "AI在确认细节"
    }

    fun statusHintOrFallback(statusHint: String?, fallback: String): String {
        val normalized = statusHint?.trim().orEmpty()
        if (normalized.isBlank()) {
            return fallback
        }
        return when (currentVoiceLanguage()) {
            VoiceLanguage.Chinese -> normalized
            VoiceLanguage.English -> if (containsCjk(normalized)) fallback else normalized
            VoiceLanguage.Japanese -> normalized
                .takeIf { !containsChineseStatusPhrase(it) }
                ?: fallback
        }
    }

    private fun containsChineseStatusPhrase(value: String): Boolean {
        val phrases = listOf(
            "正在", "确认", "细节", "回复", "切换", "场景", "听你说", "补充", "预订人", "任务"
        )
        return phrases.any { value.contains(it) }
    }

    private fun containsCjk(value: String): Boolean {
        return value.any { char ->
            char in '\u3400'..'\u9FFF' ||
                char in '\u3040'..'\u30FF' ||
                char in '\uAC00'..'\uD7AF'
        }
    }
}
