package com.vvtech.aiassistant.features.translation_call.backend

import com.vvtech.aiassistant.domain.translation.TranslationCallEnvironmentPatch
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.Base64
import org.json.JSONObject

internal data class BackendRealtimeMessage(
    val callSessionId: String,
    val environment: TranslationCallEnvironmentPatch?,
    val event: BackendRealtimeEvent
)

internal sealed interface BackendRealtimeEvent {
    data class Ready(val kind: Kind) : BackendRealtimeEvent {
        enum class Kind { AppAudio, Worker, Realtime, MerchantAudio }
    }

    data class TranslatedAudio(
        val sampleRate: Int,
        val pcmLittleEndian: ByteArray,
        val sequence: Long
    ) : BackendRealtimeEvent

    data class TranscriptDelta(
        val segmentId: String,
        val sourceLeg: String,
        val targetLeg: String,
        val kind: String,
        val text: String,
        val final: Boolean,
        val replace: Boolean
    ) : BackendRealtimeEvent

    data class ConnectPrompt(
        val segmentId: String,
        val sourceText: String,
        val translatedText: String
    ) : BackendRealtimeEvent

    data class CallEnded(val reason: String) : BackendRealtimeEvent
    data class Error(val code: String, val message: String) : BackendRealtimeEvent
    data class EnvironmentSnapshot(val phase: String) : BackendRealtimeEvent
    data class Unknown(val name: String) : BackendRealtimeEvent
}

internal object BackendRealtimeProtocol {
    fun startFrame(callSessionId: String, sequence: Long, timestampMs: Long): String =
        JSONObject()
            .put("type", "start")
            .put("protocolVersion", "java-v1")
            .put("callSessionId", callSessionId)
            .put("sequence", sequence)
            .put("timestampMs", timestampMs)
            .put("traceId", "$callSessionId:app:start")
            .put("sampleRate", 16_000)
            .put("channels", 1)
            .put("encoding", "pcm_s16le")
            .put("downlinkAudio", "binary")
            .put("payload", "")
            .toString()

    fun mediaFrame(pcmLittleEndian: ByteArray, sampleRate: Int): String =
        JSONObject()
            .put("event", "media")
            .put("audioFormat", "pcm16")
            .put("sampleRate", sampleRate)
            .put("payload", Base64.getEncoder().encodeToString(pcmLittleEndian))
            .toString()

    fun stopFrame(): String = JSONObject().put("event", "stop").toString()

    fun parseText(text: String): BackendRealtimeMessage {
        val json = JSONObject(text)
        val event = when (val name = json.optString("event").ifBlank {
            json.optString("type")
        }) {
            "app_audio_ready" -> BackendRealtimeEvent.Ready(
                BackendRealtimeEvent.Ready.Kind.AppAudio
            )
            "worker_ready" -> BackendRealtimeEvent.Ready(
                BackendRealtimeEvent.Ready.Kind.Worker
            )
            "realtime_ready" -> BackendRealtimeEvent.Ready(
                BackendRealtimeEvent.Ready.Kind.Realtime
            )
            "merchant_audio_ready" -> BackendRealtimeEvent.Ready(
                BackendRealtimeEvent.Ready.Kind.MerchantAudio
            )
            "translated_audio" -> translatedAudio(json)
            "transcript_delta" -> transcriptDelta(json)
            "connect_prompt" -> BackendRealtimeEvent.ConnectPrompt(
                segmentId = json.optString("segmentId").ifBlank {
                    "${json.optString("callSessionId")}:connect-prompt"
                },
                sourceText = json.optString("sourceText").trim(),
                translatedText = json.optString("translatedText").trim()
            )
            "call_ended" -> BackendRealtimeEvent.CallEnded(json.optString("reason").trim())
            "environment_snapshot" -> BackendRealtimeEvent.EnvironmentSnapshot(
                json.optJSONObject("environment")?.optString("phase").orEmpty()
            )
            "error" -> BackendRealtimeEvent.Error(
                json.optString("code").trim(),
                json.optString("message").ifBlank { "实时翻译服务返回错误" }
            )
            else -> BackendRealtimeEvent.Unknown(name)
        }
        return BackendRealtimeMessage(
            callSessionId = json.optString("callSessionId").trim(),
            environment = BackendTranslationEnvironmentProtocol.parse(
                json.optJSONObject("environment")
            ),
            event = event
        )
    }

    fun parseBinary(bytes: ByteArray): BackendRealtimeMessage {
        require(bytes.size >= Integer.BYTES) { "二进制音频帧缺少 header 长度" }
        val headerLength = ByteBuffer.wrap(bytes, 0, Integer.BYTES)
            .order(ByteOrder.BIG_ENDIAN)
            .int
        require(headerLength in 1..MaxBinaryHeaderBytes) { "二进制音频 header 长度无效" }
        require(bytes.size >= Integer.BYTES + headerLength) { "二进制音频帧不完整" }
        val headerStart = Integer.BYTES
        val header = JSONObject(
            bytes.copyOfRange(headerStart, headerStart + headerLength).toString(Charsets.UTF_8)
        )
        require(
            header.optString("event") == "translated_audio" ||
                header.optString("type") == "translated_audio"
        ) { "不支持的二进制实时事件" }
        val sequence = header.optLong("sequence", -1L)
        val audio = bytes.copyOfRange(headerStart + headerLength, bytes.size)
        require(audio.isNotEmpty()) { "二进制音频 payload 为空" }
        return BackendRealtimeMessage(
            callSessionId = header.optString("callSessionId").trim(),
            environment = null,
            event = BackendRealtimeEvent.TranslatedAudio(
                sampleRate = header.optInt("sampleRate"),
                pcmLittleEndian = audio,
                sequence = sequence
            )
        )
    }

    private fun translatedAudio(json: JSONObject): BackendRealtimeEvent.TranslatedAudio {
        require(json.optString("audioFormat").equals("pcm16", true)) {
            "不支持的翻译音频格式"
        }
        val bytes = runCatching {
            Base64.getDecoder().decode(json.optString("payload"))
        }.getOrElse { throw IllegalArgumentException("翻译音频 Base64 无效", it) }
        val diagnostics = json.optJSONObject("diagnostics")
        return BackendRealtimeEvent.TranslatedAudio(
            sampleRate = json.optInt("sampleRate"),
            pcmLittleEndian = bytes,
            sequence = diagnostics?.optLong("serverSequence", -1L)
                ?.takeIf { it >= 0 }
                ?: json.optLong("sequence", -1L)
        )
    }

    private fun transcriptDelta(json: JSONObject) = BackendRealtimeEvent.TranscriptDelta(
        segmentId = json.optString("segmentId").also {
            require(it.isNotBlank()) { "字幕 segmentId 缺失" }
        },
        sourceLeg = json.optString("sourceLeg").lowercase(),
        targetLeg = json.optString("targetLeg").lowercase(),
        kind = json.optString("kind").lowercase(),
        text = json.optString("text"),
        final = json.optBoolean("isFinal", false),
        replace = json.optBoolean("replace", false)
    )

    private const val MaxBinaryHeaderBytes = 4096
}
