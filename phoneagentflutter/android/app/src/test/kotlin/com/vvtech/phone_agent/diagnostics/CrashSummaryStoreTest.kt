package com.vvtech.phone_agent.diagnostics

import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File
import java.time.LocalDate
import java.time.ZoneId
import javax.crypto.KeyGenerator

class CrashSummaryStoreTest {
    @get:Rule val temporary = TemporaryFolder()
    private val key = KeyGenerator.getInstance("AES").apply { init(256) }.generateKey()
    private val scopeA = "a".repeat(64)
    private val scopeB = "b".repeat(64)
    private fun summary() = CrashSummary(mainThread = true, kind = "state")

    @Test fun encryptedRoundTripRestartScopeAndExactAck() {
        val directory = temporary.newFolder()
        val store = CrashSummaryStore(directory, { key })
        val first = summary()
        val second = summary()
        store.save(scopeA, first)
        store.save(scopeB, second)
        store.save(null, summary())
        assertEquals(3, directory.listFiles()!!.size)
        directory.listFiles()!!.forEach {
            assertFalse(String(it.readBytes()).contains("state"))
            assertTrue(it.length() < 1024)
        }
        val restarted = CrashSummaryStore(directory, { create -> assertFalse(create); key })
        assertEquals(listOf(first), restarted.read(scopeA))
        restarted.acknowledge(scopeB, listOf(first.id))
        assertEquals(listOf(first), restarted.read(scopeA))
        restarted.acknowledge(scopeA, listOf(first.id))
        assertEquals(emptyList<CrashSummary>(), restarted.read(scopeA))
        assertEquals(listOf(second), restarted.read(scopeB))
        assertTrue(directory.listFiles()!!.any { it.name.startsWith("unassigned_") })
    }

    @Test fun startupSummaryRestoresWithoutCrossingAccountPartitions() {
        val directory = temporary.newFolder()
        val store = CrashSummaryStore(directory, { key })
        val startup = summary()
        val other = summary()
        store.save(null, startup)
        store.save(scopeB, other)
        val restarted = CrashSummaryStore(directory, { key })
        assertEquals(listOf(startup), restarted.readStartup())
        assertTrue(restarted.read(scopeA).isEmpty())
        restarted.acknowledgeStartup(listOf(other.id))
        assertEquals(listOf(other), restarted.read(scopeB))
        assertEquals(listOf(startup), restarted.readStartup())
        restarted.acknowledgeStartup(listOf(startup.id))
        assertTrue(restarted.readStartup().isEmpty())
        assertEquals(listOf(other), restarted.read(scopeB))
    }

    @Test fun tamperAndRenamedScopeFailWithoutDeletingData() {
        val directory = temporary.newFolder()
        val store = CrashSummaryStore(directory, { key })
        val first = summary()
        store.save(scopeA, first)
        val file = directory.listFiles()!!.single()
        val renamed = File(directory, "${scopeB}_${first.id}.crash")
        assertTrue(file.renameTo(renamed))
        assertThrows(Exception::class.java) { store.read(scopeB) }
        assertTrue(renamed.renameTo(file))
        val bytes = file.readBytes()
        bytes[bytes.lastIndex] = (bytes.last().toInt() xor 1).toByte()
        file.writeBytes(bytes)
        assertThrows(Exception::class.java) { store.read(scopeA) }
        assertTrue(file.exists())
    }

    @Test fun missingKeyNeverReplacesExistingArchive() {
        val directory = temporary.newFolder()
        CrashSummaryStore(directory, { key }).save(scopeA, summary())
        val original = directory.listFiles()!!.single().readBytes()
        val store = CrashSummaryStore(directory, { create ->
            assertFalse(create)
            throw IllegalStateException("missing key")
        })
        assertThrows(Exception::class.java) { store.save(scopeA, summary()) }
        assertThrows(Exception::class.java) { store.read(scopeA) }
        assertArrayEquals(original, directory.listFiles()!!.single().readBytes())
    }

    @Test fun capRetentionAndUnknownFilePreservation() {
        val directory = temporary.newFolder()
        val store = CrashSummaryStore(directory, { key })
        val unrelated = File(directory, "user-note").apply { writeText("keep") }
        val unfinished = File(directory, "${scopeA}_${summary().id}.crash.pending").apply { writeText("incomplete") }
        val unknownPending = File(directory, "unknown.pending").apply { writeText("keep") }
        repeat(35) { store.save(scopeA, summary()) }
        assertFalse(unfinished.exists())
        assertTrue(unknownPending.exists())
        assertEquals(32, store.read(scopeA).size)
        val files = directory.listFiles()!!.filter { it.extension == "crash" }
        fun millis(days: Long) = LocalDate.now().minusDays(days)
            .atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli()
        assertTrue(files[0].setLastModified(millis(15)))
        assertTrue(files[1].setLastModified(millis(14)))
        assertEquals(31, store.read(scopeA).size)
        assertTrue(files[1].exists())
        assertEquals("keep", unrelated.readText())
    }

    @Test fun pathsAndSummaryFieldsAreStrictlyBounded() {
        val store = CrashSummaryStore(temporary.newFolder(), { key })
        assertThrows(IllegalArgumentException::class.java) { store.save("../private", summary()) }
        assertThrows(IllegalArgumentException::class.java) { store.read("unassigned") }
        assertThrows(IllegalArgumentException::class.java) { store.acknowledge(scopeA, listOf("../private")) }
        assertThrows(IllegalArgumentException::class.java) { CrashSummary(mainThread = true, kind = "token") }
    }

    @Test fun randomNonceChangesCiphertextForSamePayload() {
        val directory = temporary.newFolder()
        val store = CrashSummaryStore(directory, { key })
        val value = summary()
        store.save(scopeA, value)
        val first = directory.listFiles()!!.single().readBytes()
        store.save(scopeA, value)
        assertFalse(first.contentEquals(directory.listFiles()!!.single().readBytes()))
        assertEquals(listOf(value), store.read(scopeA))
    }
}
