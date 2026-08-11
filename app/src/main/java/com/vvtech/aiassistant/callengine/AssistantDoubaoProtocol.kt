package com.vvtech.aiassistant.callengine

internal object AssistantDoubaoProtocol {
    fun headers(config: AssistantRealtimeModelConfig): Map<String, String> =
        if (config.websocketUrl.contains("/ws/assistant/translation-model/")) {
            mapOf("Authorization" to "Bearer ${config.apiKey}")
        } else {
        linkedMapOf(
            "X-Api-Key" to config.apiKey,
            "X-Api-Resource-Id" to config.model
        ).apply {
            if (config.apiKey.isBlank() && config.accessKey.isNotBlank()) {
                remove("X-Api-Key")
                put("X-Api-Access-Key", config.accessKey)
            }
        }
        }

    fun start(
        config: AssistantRealtimeModelConfig,
        sourceLanguage: String,
        targetLanguage: String,
        connectionId: String,
        sessionId: String,
        sequence: Int
    ): ByteArray = AssistantDoubaoProto.encode(
        AssistantDoubaoRequest(
            meta = meta(config, connectionId, sessionId, sequence),
            event = AssistantDoubaoProto.StartSession,
            sourceAudio = AssistantDoubaoAudio(
                format = "wav",
                codec = "raw",
                language = language(sourceLanguage, "zh"),
                rate = 16_000,
                bits = 16,
                channel = 1
            ),
            targetAudio = AssistantDoubaoAudio(
                format = "pcm",
                language = language(targetLanguage, "en"),
                rate = 16_000
            ),
            parameters = AssistantDoubaoParameters(
                mode = "s2s",
                sourceLanguage = language(sourceLanguage, "zh"),
                targetLanguage = language(targetLanguage, "en")
            )
        )
    )

    fun audio(
        connectionId: String,
        sessionId: String,
        sequence: Int,
        pcm16k: ShortArray
    ): ByteArray = AssistantDoubaoProto.encode(
        AssistantDoubaoRequest(
            meta = emptyMeta(connectionId, sessionId, sequence),
            event = AssistantDoubaoProto.TaskRequest,
            sourceAudio = AssistantDoubaoAudio(
                rate = 16_000,
                bits = 16,
                channel = 1,
                data = AssistantPcmResampler.toLittleEndian(pcm16k)
            ),
            targetAudio = null,
            parameters = null
        )
    )

    fun finish(connectionId: String, sessionId: String, sequence: Int): ByteArray =
        AssistantDoubaoProto.encode(
            AssistantDoubaoRequest(
                meta = emptyMeta(connectionId, sessionId, sequence),
                event = AssistantDoubaoProto.FinishSession,
                sourceAudio = null,
                targetAudio = null,
                parameters = null
            )
        )

    fun silenceFrame(): ShortArray = ShortArray(320)

    private fun meta(
        config: AssistantRealtimeModelConfig,
        connectionId: String,
        sessionId: String,
        sequence: Int
    ) = AssistantDoubaoRequestMeta(
        endpoint = config.model,
        appKey = "",
        resourceId = config.model,
        connectionId = connectionId,
        sessionId = sessionId,
        sequence = sequence
    )

    private fun emptyMeta(connectionId: String, sessionId: String, sequence: Int) =
        AssistantDoubaoRequestMeta("", "", "", connectionId, sessionId, sequence)

    private fun language(value: String, fallback: String): String =
        value.trim().substringBefore('-').ifBlank { fallback }
}
