package com.vvtech.aiassistant.features.assistant_voice

private val VOICE_RECOGNIZED_INPUT_IGNORED_CHARS =
    Regex("""[\s\p{Punct}，。！？、；：,.!?;:"'“”‘’（）()\[\]【】]+""")

internal class VoiceRecognizedInputDedupTracker {
    private var inputGeneration = 0L
    private var acceptedGeneration: Long? = null
    private var acceptedFingerprint = ""

    fun beginInput(): Long {
        inputGeneration += 1
        return inputGeneration
    }

    fun currentGeneration(): Long = inputGeneration

    fun markAccepted(text: String): Long {
        acceptedGeneration = inputGeneration
        acceptedFingerprint = fingerprint(text)
        return inputGeneration
    }

    fun isDuplicateInCurrentInput(text: String): Boolean {
        val candidate = fingerprint(text)
        return candidate.isNotBlank() &&
            acceptedGeneration == inputGeneration &&
            candidate == acceptedFingerprint
    }

    fun reset() {
        inputGeneration = 0L
        acceptedGeneration = null
        acceptedFingerprint = ""
    }

    private fun fingerprint(text: String): String =
        text.trim()
            .lowercase()
            .replace(VOICE_RECOGNIZED_INPUT_IGNORED_CHARS, "")
}
