package com.vvtech.aiassistant.features.assistant_voice_clone.enrollment

import com.vvtech.aiassistant.data.repository.voiceclone.VoiceCloneCompletionStage
import com.vvtech.aiassistant.data.repository.voiceclone.voiceCloneCompletionStage

internal object VoiceCloneCompletionFailureMessagePolicy {

    fun messageFor(throwable: Throwable): String =
        when (throwable.voiceCloneCompletionStage()) {
            VoiceCloneCompletionStage.MFVC_MATERIAL ->
                "认证材料获取失败，请重新认证。"
            VoiceCloneCompletionStage.AUDIO_QUALITY ->
                "跟读录音不清晰，请在安静环境中使用正常语速连续朗读后重新认证。"
            VoiceCloneCompletionStage.ASR_PROVIDER ->
                "跟读语音识别失败，请重新认证。"
            VoiceCloneCompletionStage.ASR_CONTENT ->
                "朗读内容与提示不一致，请连续清晰地读完整句话后重新认证。"
            VoiceCloneCompletionStage.CLONE_PROVIDER,
            VoiceCloneCompletionStage.CLONE_SUBMISSION_UNKNOWN ->
                "声音克隆失败，请重新开始。"
            null ->
                "跟读语音处理失败，请重新认证。"
        }
}
