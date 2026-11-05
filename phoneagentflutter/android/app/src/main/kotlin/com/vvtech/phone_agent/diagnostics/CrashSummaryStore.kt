package com.vvtech.phone_agent.diagnostics

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.DataInputStream
import java.io.DataOutputStream
import java.io.File
import java.io.FileOutputStream
import java.time.LocalDate
import java.time.ZoneId
import javax.crypto.Cipher
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** JVM-testable, bounded staging. The supplied directory is application-private. */
class CrashSummaryStore(
    private val directory: File,
    private val key: (create: Boolean) -> SecretKey,
    private val today: () -> LocalDate = { LocalDate.now() },
) {
    @Synchronized
    fun save(scope: String?, summary: CrashSummary) {
        require(scope == null || CrashSummary.SCOPE.matches(scope))
        check(directory.isDirectory || directory.mkdirs())
        prunePending()
        val file = File(directory, "${scope ?: "unassigned"}_${summary.id}.crash")
        val plain = ByteArrayOutputStream().also { buffer ->
            DataOutputStream(buffer).use {
                it.writeInt(1)
                it.writeLong(summary.time)
                it.writeBoolean(summary.mainThread)
                it.writeUTF(summary.kind)
            }
        }.toByteArray()
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        // Do not silently replace a missing key while existing encrypted files remain.
        cipher.init(Cipher.ENCRYPT_MODE, key(files().isEmpty()))
        cipher.updateAAD(file.name.toByteArray(Charsets.UTF_8))
        val encrypted = cipher.iv + cipher.doFinal(plain)
        val temporary = File(directory, "${file.name}.pending")
        try {
            FileOutputStream(temporary).use { it.write(encrypted); it.fd.sync() }
            check(temporary.renameTo(file))
        } finally {
            temporary.delete()
        }
        prune()
    }

    @Synchronized
    fun read(scope: String): List<CrashSummary> {
        require(CrashSummary.SCOPE.matches(scope))
        return readPartition(scope)
    }

    /** Anonymous boot summaries contain no account or throwable text. */
    @Synchronized
    fun readStartup(): List<CrashSummary> = readPartition("unassigned")

    private fun readPartition(scope: String): List<CrashSummary> {
        prunePending()
        prune()
        return files().filter { it.name.startsWith("${scope}_") }.map { file ->
            require(file.length() in 29L..1024L)
            val encrypted = file.readBytes()
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE, key(false), GCMParameterSpec(128, encrypted, 0, 12))
            cipher.updateAAD(file.name.toByteArray(Charsets.UTF_8))
            DataInputStream(ByteArrayInputStream(cipher.doFinal(encrypted, 12, encrypted.size - 12))).use {
                require(it.readInt() == 1)
                val value = CrashSummary(
                    id = file.name.removePrefix("${scope}_").removeSuffix(".crash"),
                    time = it.readLong(), mainThread = it.readBoolean(), kind = it.readUTF(),
                )
                require(it.available() == 0)
                value
            }
        }.sortedBy { it.time }
    }

    @Synchronized
    fun acknowledge(scope: String, ids: List<String>) {
        require(CrashSummary.SCOPE.matches(scope) && ids.size <= 32)
        require(ids.all { CrashSummary.ID.matches(it) })
        ids.forEach { id ->
            val file = File(directory, "${scope}_${id}.crash")
            check(!file.exists() || file.delete())
        }
    }

    @Synchronized
    fun acknowledgeStartup(ids: List<String>) {
        require(ids.size <= 32 && ids.all { CrashSummary.ID.matches(it) })
        ids.forEach { id ->
            val file = File(directory, "unassigned_${id}.crash")
            check(!file.exists() || file.delete())
        }
    }

    private fun files(): List<File> = directory.listFiles()?.filter {
        it.isFile && NAME.matches(it.name)
    } ?: emptyList()

    private fun prunePending() {
        // Only interrupted writes of this store, never arbitrary user files.
        directory.listFiles()?.filter {
            it.isFile && it.name.endsWith(".pending") &&
                NAME.matches(it.name.removeSuffix(".pending"))
        }?.forEach { check(it.delete()) }
    }

    private fun prune() {
        val cutoff = today().minusDays(14)
        files().filter {
            java.time.Instant.ofEpochMilli(it.lastModified()).atZone(ZoneId.systemDefault())
                .toLocalDate().isBefore(cutoff)
        }.forEach { check(it.delete()) }
        files().sortedWith(compareBy<File> { it.lastModified() }.thenBy { it.name })
            .dropLast(32).forEach { check(it.delete()) }
    }

    companion object {
        private val NAME = Regex("(?:[0-9a-f]{64}|unassigned)_[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\\.crash")
    }
}
