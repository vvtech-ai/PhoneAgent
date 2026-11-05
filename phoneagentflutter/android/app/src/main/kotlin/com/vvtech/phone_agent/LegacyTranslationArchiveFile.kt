package com.vvtech.phone_agent

import java.io.File
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.charset.CodingErrorAction
import java.nio.charset.StandardCharsets
import java.security.MessageDigest

/** Fixed single-account source. Never enumerate, mutate, or log old journals. */
internal object LegacyTranslationArchiveFile {
    const val MAX_BYTES = 8 * 1024 * 1024

    fun fileName(account: String): String {
        require(account.isNotBlank() && account.length <= 256 && account == account.trim())
        val hash = MessageDigest.getInstance("SHA-256")
            .digest(account.toByteArray(StandardCharsets.UTF_8))
            .joinToString("") { "%02x".format(it) }
        return "pending-${hash.take(32)}.json"
    }

    fun read(filesDirectory: File, account: String): String? {
        val base = filesDirectory.canonicalFile
        val root = File(base, "realtime-translation/pending")
        check(root.canonicalFile == root.absoluteFile)
        val file = File(root, fileName(account))
        check(file.canonicalFile == file.absoluteFile)
        if (!file.exists()) return null
        check(file.isFile && file.length() <= MAX_BYTES)
        // Bounded even if the file grows after the initial length check.
        val bytes = file.inputStream().use { input ->
            val output = ByteArrayOutputStream()
            val buffer = ByteArray(8192)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                check(output.size() + count <= MAX_BYTES)
                output.write(buffer, 0, count)
            }
            output.toByteArray()
        }
        return StandardCharsets.UTF_8.newDecoder()
            .onMalformedInput(CodingErrorAction.REPORT)
            .onUnmappableCharacter(CodingErrorAction.REPORT)
            .decode(ByteBuffer.wrap(bytes)).toString()
    }
}
