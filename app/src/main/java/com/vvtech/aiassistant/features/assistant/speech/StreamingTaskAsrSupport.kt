package com.vvtech.aiassistant.features.assistant.speech

import com.google.gson.JsonParser

internal data class StreamingAsrTranscript(
    val text: String,
    val isFinal: Boolean
)

internal fun buildStreamingAsrAuthHeaders(
    appId: String,
    apiKey: String,
    accessKey: String,
    resourceId: String,
    connectId: String
): Map<String, String> {
    val headers = linkedMapOf(
        "X-Api-Resource-Id" to resourceId,
        "X-Api-Connect-Id" to connectId
    )
    if (appId.isBlank() && accessKey.isBlank()) {
        headers["X-Api-Key"] = apiKey
    } else {
        headers["X-Api-App-Key"] = appId.ifBlank { apiKey }
        headers["X-Api-Access-Key"] = accessKey
    }
    return headers
}

internal fun parseStreamingAsrResponseJson(
    json: String,
    isFinalPacket: Boolean
): StreamingAsrTranscript? {
    val root = runCatching { JsonParser().parse(json).asJsonObject }.getOrNull() ?: return null
    val result = root.get("result")?.asJsonObject ?: return null
    val utterances = result.getAsJsonArray("utterances")
    if (utterances != null && utterances.size() > 0) {
        val parts = mutableListOf<String>()
        var hasDefinite = false
        for (itemElement in utterances) {
            if (!itemElement.isJsonObject) continue
            val item = itemElement.asJsonObject
            val text = item.get("text")?.asString.orEmpty().trim()
            if (text.isNotEmpty() && !looksLikeStreamingAsrMetadata(text)) {
                parts.add(text)
            }
            hasDefinite = hasDefinite || (item.get("definite")?.asBoolean ?: false)
        }
        val combined = parts.joinToString("")
        if (combined.isNotBlank()) {
            return StreamingAsrTranscript(combined, hasDefinite || isFinalPacket)
        }
    }
    val fallback = result.get("text")?.asString.orEmpty().trim()
    return if (fallback.isBlank() || looksLikeStreamingAsrMetadata(fallback)) {
        null
    } else {
        StreamingAsrTranscript(fallback, isFinalPacket)
    }
}

private fun looksLikeStreamingAsrMetadata(text: String): Boolean {
    return Regex("""[A-Za-z][A-Za-z0-9]*-[A-Za-z][A-Za-z0-9]*v?\d+\.\d+""")
        .containsMatchIn(text.trim())
}
