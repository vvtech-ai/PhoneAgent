package com.vvtech.aiassistant.data.repository.voiceclone

import com.google.gson.JsonParser
import retrofit2.HttpException

internal enum class VoiceCloneCompletionStage {
    MFVC_MATERIAL,
    AUDIO_QUALITY,
    ASR_PROVIDER,
    ASR_CONTENT,
    CLONE_PROVIDER,
    CLONE_SUBMISSION_UNKNOWN
}

internal class VoiceCloneCompletionException(
    val httpStatus: Int,
    val stage: VoiceCloneCompletionStage?,
    cause: Throwable
) : IllegalStateException("声音克隆完成失败", cause)

internal fun HttpException.toVoiceCloneCompletionException(): VoiceCloneCompletionException {
    val rawBody = runCatching { response()?.errorBody()?.string() }.getOrNull()
    val stageName = runCatching {
        JsonParser().parse(rawBody)
            .asJsonObject
            .getAsJsonObject("data")
            .get("stage")
            .asString
    }.getOrNull()
    val stage = runCatching {
        VoiceCloneCompletionStage.valueOf(stageName.orEmpty())
    }.getOrNull()
    return VoiceCloneCompletionException(code(), stage, this)
}

internal fun Throwable.voiceCloneCompletionHttpStatus(): Int? =
    generateSequence(this) { it.cause }
        .filterIsInstance<VoiceCloneCompletionException>()
        .firstOrNull()
        ?.httpStatus

internal fun Throwable.voiceCloneCompletionStage(): VoiceCloneCompletionStage? =
    generateSequence(this) { it.cause }
        .filterIsInstance<VoiceCloneCompletionException>()
        .firstOrNull()
        ?.stage
