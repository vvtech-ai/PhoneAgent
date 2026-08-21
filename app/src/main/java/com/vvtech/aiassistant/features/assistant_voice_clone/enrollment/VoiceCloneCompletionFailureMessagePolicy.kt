package com.vvtech.aiassistant.features.assistant_voice_clone.enrollment

import com.vvtech.aiassistant.data.repository.voiceclone.VoiceCloneCompletionStage
import com.vvtech.aiassistant.data.repository.voiceclone.voiceCloneCompletionStage
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText

internal object VoiceCloneCompletionFailureMessagePolicy {

    fun messageFor(throwable: Throwable): String =
        when (throwable.voiceCloneCompletionStage()) {
            VoiceCloneCompletionStage.MFVC_MATERIAL ->
                currentAppText("认证材料获取失败，请重新认证。", "Verification materials could not be retrieved. Please verify again.")
            VoiceCloneCompletionStage.AUDIO_QUALITY ->
                currentAppText("跟读录音不清晰，请在安静环境中使用正常语速连续朗读后重新认证。", "The read-aloud recording is unclear. Verify again in a quiet place and read the full sentence at a natural pace.")
            VoiceCloneCompletionStage.ASR_PROVIDER ->
                currentAppText("跟读语音识别失败，请重新认证。", "Read-aloud speech recognition failed. Please verify again.")
            VoiceCloneCompletionStage.ASR_CONTENT ->
                currentAppText("朗读内容与提示不一致，请连续清晰地读完整句话后重新认证。", "The read-aloud content did not match the prompt. Verify again after reading the full sentence clearly.")
            VoiceCloneCompletionStage.CLONE_PROVIDER,
            VoiceCloneCompletionStage.CLONE_SUBMISSION_UNKNOWN ->
                currentAppText("声音克隆失败，请重新开始。", "Voice cloning failed. Please start again.")
            null ->
                currentAppText("跟读语音处理失败，请重新认证。", "Read-aloud audio processing failed. Please verify again.")
        }
}
