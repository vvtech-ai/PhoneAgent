package com.vvtech.phone_agent

import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File
import java.nio.file.Files

class LegacyTranslationArchiveFileTest {
    @get:Rule val temporary = TemporaryFolder()
    private fun target(): File = File(temporary.root,
        "realtime-translation/pending/${LegacyTranslationArchiveFile.fileName("a")}")

    @Test fun exactAccountHashMissingAndUtf8ReadOnly() {
        assertEquals("pending-ca978112ca1bbdcafac231b39a23dc4d.json",
            LegacyTranslationArchiveFile.fileName("a"))
        assertNull(LegacyTranslationArchiveFile.read(temporary.root, "a"))
        val file = target()
        requireNotNull(file.parentFile).mkdirs()
        file.writeText("[合成]")
        assertEquals("[合成]", LegacyTranslationArchiveFile.read(temporary.root, "a"))
        assertNull(LegacyTranslationArchiveFile.read(temporary.root, "b"))
        assertEquals("[合成]", file.readText())
    }

    @Test fun rejectsOversizeAndInvalidUtf8WithoutModifyingSource() {
        val file = target()
        requireNotNull(file.parentFile).mkdirs()
        file.writeBytes(ByteArray(LegacyTranslationArchiveFile.MAX_BYTES + 1))
        assertThrows(IllegalStateException::class.java) {
            LegacyTranslationArchiveFile.read(temporary.root, "a")
        }
        assertEquals((LegacyTranslationArchiveFile.MAX_BYTES + 1).toLong(), file.length())
        file.writeBytes(byteArrayOf(0xC3.toByte(), 0x28))
        assertThrows(java.nio.charset.CharacterCodingException::class.java) {
            LegacyTranslationArchiveFile.read(temporary.root, "a")
        }
        assertEquals(2L, file.length())
    }

    @Test fun symbolicLinkCannotEscapePrivatePendingDirectory() {
        val file = target()
        requireNotNull(file.parentFile).mkdirs()
        val outside = temporary.newFile("outside.json")
        outside.writeText("synthetic")
        Files.createSymbolicLink(file.toPath(), outside.toPath())
        assertThrows(IllegalStateException::class.java) {
            LegacyTranslationArchiveFile.read(temporary.root, "a")
        }
        assertEquals("synthetic", outside.readText())
    }

    @Test fun missingAccountAndDirectoryAreNotValidRecords() {
        for (account in listOf("", " ", " a", "a".repeat(257))) {
            assertThrows(IllegalArgumentException::class.java) {
                LegacyTranslationArchiveFile.fileName(account)
            }
        }
        target().mkdirs()
        assertThrows(IllegalStateException::class.java) {
            LegacyTranslationArchiveFile.read(temporary.root, "a")
        }
    }
}
