package com.vvtech.phone_agent

import java.io.ByteArrayInputStream
import java.io.DataInputStream

/** v65 DataOutputStream layout, including Java modified UTF (not UTF-8 JSON). */
internal object LegacyCertifiedRecordingPayload {
    const val MAX_AUDIO = 10 * 1024 * 1024
    const val MAX_ENCRYPTED = 11 * 1024 * 1024

    fun decode(bytes: ByteArray): Map<String, Any> {
        require(bytes.size in 5..MAX_ENCRYPTED)
        return DataInputStream(ByteArrayInputStream(bytes)).use { input ->
            val version = input.readInt()
            if (version != 1) throw LegacyRecordingUnsupported()
            val names = listOf("accountRef", "personFingerprint", "audioSha256", "scriptVersion", "receipt")
            val metadata = mutableMapOf<String, Any>("version" to version)
            names.forEach { name ->
                val value = input.readUTF()
                require(value.isNotBlank())
                metadata[name] = value
            }
            val length = input.readInt()
            require(length in 1..MAX_AUDIO && input.available() == length)
            val audio = ByteArray(length)
            input.readFully(audio)
            metadata["audio"] = audio
            metadata
        }
    }
}

internal class LegacyRecordingUnsupported : Exception()
