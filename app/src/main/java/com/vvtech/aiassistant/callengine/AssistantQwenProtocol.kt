package com.vvtech.aiassistant.callengine

import java.util.Base64
import java.util.UUID
import org.json.JSONArray
import org.json.JSONObject

internal object AssistantQwenProtocol {
    fun modelUrl(config: AssistantRealtimeModelConfig): String =
        "${config.websocketUrl}?model=${config.model}"

    fun sessionUpdate(
        config: AssistantRealtimeModelConfig,
        sourceLanguage: String,
        targetLanguage: String
    ): String = JSONObject()
        .put("event_id", eventId())
        .put("type", "session.update")
        .put(
            "session",
            JSONObject()
                .put("modalities", JSONArray().put("text").put("audio"))
                .put("input_audio_format", "pcm")
                .put("sample_rate", 16_000)
                .put(
                    "input_audio_transcription",
                    JSONObject()
                        .put("model", config.model)
                        .put("language", normalizeLanguage(sourceLanguage, "zh"))
                )
                .put("output_audio_format", "pcm")
                .put("voice", config.voice)
                .put(
                    "translation",
                    JSONObject().put("language", normalizeLanguage(targetLanguage, "en"))
                )
        )
        .toString()

    fun appendAudio(pcm16k: ShortArray): String = JSONObject()
        .put("event_id", eventId())
        .put("type", "input_audio_buffer.append")
        .put(
            "audio",
            Base64.getEncoder().encodeToString(AssistantPcmResampler.toLittleEndian(pcm16k))
        )
        .toString()

    fun finish(): String = JSONObject()
        .put("event_id", eventId())
        .put("type", "session.finish")
        .toString()

    private fun normalizeLanguage(value: String, fallback: String): String {
        val normalized = value.trim().lowercase().replace('_', '-').substringBefore('-')
        return when (normalized) {
            "zh", "cn", "chinese" -> "zh"
            "en", "english" -> "en"
            "ja", "jp", "japanese" -> "ja"
            else -> normalized.ifBlank { fallback }
        }
    }

    private fun eventId(): String = "event-${UUID.randomUUID()}"
}

internal sealed interface AssistantQwenEvent {
    data class Transcript(val value: AssistantTranslationTranscript) : AssistantQwenEvent
    data class Audio(val pcm: ShortArray) : AssistantQwenEvent
    data class Error(val message: String) : AssistantQwenEvent
    object ResponseDone : AssistantQwenEvent
    object Finished : AssistantQwenEvent
}

internal class AssistantQwenEventParser(
    private val speaker: String,
    private val sourceLanguage: String,
    private val targetLanguage: String,
    private val outputSampleRate: Int
) {
    private var sourceText = ""
    private var translatedText = ""
    private var turnId = UUID.randomUUID().toString()

    fun parse(payload: String): AssistantQwenEvent? {
        val json = runCatching { JSONObject(payload) }.getOrNull() ?: return null
        return when (json.optString("type")) {
            "conversation.item.input_audio_transcription.text" -> {
                sourceText = text(json)
                transcript(final = false)
            }
            "conversation.item.input_audio_transcription.completed" -> {
                sourceText = text(json).ifBlank { sourceText }
                transcript(final = false)
            }
            "response.audio_transcript.text",
            "response.text.text" -> {
                translatedText = text(json)
                transcript(final = false)
            }
            "response.audio_transcript.delta",
            "response.text.delta" -> {
                translatedText += text(json)
                transcript(final = false)
            }
            "response.audio_transcript.done",
            "response.text.done" -> {
                translatedText = text(json).ifBlank { translatedText }
                transcript(final = true).also { resetTurn() }
            }
            "response.audio.delta" -> audio(json)
            "response.done" -> AssistantQwenEvent.ResponseDone
            "session.finished" -> AssistantQwenEvent.Finished
            "error" -> AssistantQwenEvent.Error(
                json.optJSONObject("error")?.optString("message").orEmpty()
                    .ifBlank { json.optString("message") }
                    .ifBlank { "Qwen realtime provider error" }
            )
            else -> null
        }
    }

    private fun transcript(final: Boolean): AssistantQwenEvent.Transcript? {
        if (sourceText.isBlank() && translatedText.isBlank()) return null
        return AssistantQwenEvent.Transcript(
            AssistantTranslationTranscript(
                id = turnId,
                speaker = speaker,
                sourceLanguage = sourceLanguage,
                sourceText = sourceText.trim(),
                translatedLanguage = targetLanguage,
                translatedText = translatedText.trim(),
                final = final
            )
        )
    }

    private fun audio(json: JSONObject): AssistantQwenEvent.Audio? {
        val encoded = json.optString("delta")
        if (encoded.isBlank()) return null
        val source = AssistantPcmResampler.fromLittleEndian(Base64.getDecoder().decode(encoded))
        val pcm16k = if (outputSampleRate == 16_000) {
            source
        } else {
            AssistantPcmResampler.resample(source, outputSampleRate, 16_000)
        }
        return AssistantQwenEvent.Audio(pcm16k)
    }

    private fun text(json: JSONObject): String =
        json.optString("transcript")
            .ifBlank { json.optString("text") }
            .ifBlank { json.optString("delta") }

    private fun resetTurn() {
        sourceText = ""
        translatedText = ""
        turnId = UUID.randomUUID().toString()
    }
}
