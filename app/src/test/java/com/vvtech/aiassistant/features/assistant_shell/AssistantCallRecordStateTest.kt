package com.vvtech.aiassistant.features.assistant_shell

import com.vvtech.aiassistant.features.assistant.FinalCallRecord
import com.vvtech.aiassistant.features.assistant.DialCallKind
import com.vvtech.aiassistant.features.assistant.decodeFinalCallRecords
import com.vvtech.aiassistant.features.assistant.encodeFinalCallRecords
import com.vvtech.aiassistant.features.assistant.finalCallRecordsStorageKey
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantCallRecordStateTest {
    @Test
    fun loadForAccountUsesScopedStorageAndClearsExistingRecords() {
        val store = MemoryCallRecordStore(
            finalCallRecordsStorageKey("account-1") to encodeFinalCallRecords(
                listOf(record("old"), record("older"))
            )
        )
        val state = AssistantCallRecordState(store)
        state.appendForAccount("other", record("temporary"))

        state.loadForAccount("account-1")

        assertEquals(listOf("old", "older"), state.records.map { it.title })
        assertEquals("old", state.latestRecord()?.title)
    }

    @Test
    fun blankAccountLoadOnlyClearsMemoryWithoutWriting() {
        val store = MemoryCallRecordStore()
        val state = AssistantCallRecordState(store)
        state.appendForAccount("account-1", record("existing"))

        state.loadForAccount("")

        assertTrue(state.records.isEmpty())
        assertEquals(1, store.writeCount)
    }

    @Test
    fun appendAddsRecordToTopAndPersistsWhenAccountExists() {
        val store = MemoryCallRecordStore()
        val state = AssistantCallRecordState(store)

        state.appendForAccount("account-1", record("first"))
        state.appendForAccount("account-1", record("second"))

        assertEquals(listOf("second", "first"), state.records.map { it.title })
        val persisted = decodeFinalCallRecords(store[finalCallRecordsStorageKey("account-1")])
        assertEquals(listOf("second", "first"), persisted.map { it.title })
        assertEquals(2, store.writeCount)
    }

    @Test
    fun appendIfAbsentUsesCallIdentityWithoutDroppingASeparateCall() {
        val store = MemoryCallRecordStore()
        val state = AssistantCallRecordState(store)
        val first = record("first").copy(
            callId = "call-1",
            callKind = DialCallKind.TRANSLATION
        )

        assertTrue(state.appendIfAbsentForAccount("account-1", first))
        assertFalse(state.appendIfAbsentForAccount("account-1", first.copy(meta = "changed")))
        assertTrue(
            state.appendIfAbsentForAccount(
                "account-1",
                first.copy(title = "second", callId = "call-2")
            )
        )

        assertEquals(listOf("second", "first"), state.records.map { it.title })
        assertEquals(2, store.writeCount)
    }

    @Test
    fun clearForAccountHonorsPersistFlagAndBlankAccountGuard() {
        val store = MemoryCallRecordStore()
        val state = AssistantCallRecordState(store)
        state.appendForAccount("account-1", record("first"))

        state.clearForAccount("account-1", persist = false)

        assertTrue(state.records.isEmpty())
        assertEquals(1, store.writeCount)

        state.appendForAccount("", record("blank-account"))
        state.clearForAccount("", persist = true)

        assertTrue(state.records.isEmpty())
        assertEquals(1, store.writeCount)

        state.appendForAccount("account-1", record("second"))
        state.clearForAccount("account-1", persist = true)

        assertTrue(state.records.isEmpty())
        assertEquals(emptyList<FinalCallRecord>(), decodeFinalCallRecords(store[finalCallRecordsStorageKey("account-1")]))
        assertEquals(3, store.writeCount)
    }

    @Test
    fun assistantRootScreenDelegatesCallRecordState() {
        val root =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant/AssistantRootScreen.kt")
                .readText(Charsets.UTF_8)
        val runtimeGraph =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootRuntimeGraph.kt")
                .readText(Charsets.UTF_8)
        val primaryShell =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantRootPrimaryShellEffects.kt")
                .readText(Charsets.UTF_8)
        val holder =
            sourceFile("src/main/java/com/vvtech/aiassistant/features/assistant_shell/AssistantCallRecordState.kt")
                .readText(Charsets.UTF_8)

        assertTrue(root.contains("val callRecordState = rootRuntimeGraph.state.callRecord"))
        assertTrue(runtimeGraph.contains("rememberAssistantCallRecordState(prefs)"))
        assertTrue(primaryShell.contains("state.callRecord::loadForAccount"))
        assertTrue(primaryShell.contains("state.callRecord.clearForAccount"))
        assertTrue(root.contains("callRecordState.records"))
        assertTrue(runtimeGraph.contains("callRecordState.appendIfAbsentForAccount"))
        assertTrue(holder.contains("appendIfAbsentForAccount"))
        assertTrue(holder.contains("mutableStateListOf<FinalCallRecord>()"))
        assertTrue(holder.contains("encodeFinalCallRecords"))
        assertTrue(holder.contains("decodeFinalCallRecords"))
        assertTrue(holder.contains("finalCallRecordsStorageKey"))

        assertEquals(-1, root.indexOf("mutableStateListOf<FinalCallRecord>()"))
        assertEquals(-1, root.indexOf("persistCallRecordsForAccount"))
        assertEquals(-1, root.indexOf("clearCallRecordsForCurrentAccount"))
        assertEquals(-1, root.indexOf("appendCallRecordForCurrentAccount"))
        assertEquals(-1, root.indexOf("loadCallRecordsForAccount"))
        assertEquals(-1, root.indexOf("encodeFinalCallRecords"))
        assertEquals(-1, root.indexOf("decodeFinalCallRecords"))
        assertEquals(-1, root.indexOf("finalCallRecordsStorageKey"))
    }

    private class MemoryCallRecordStore(
        vararg initial: Pair<String, String>
    ) : AssistantCallRecordStore {
        private val values = mutableMapOf(*initial)
        var writeCount = 0

        override fun getString(key: String): String? = values[key]

        override fun putString(key: String, value: String) {
            values[key] = value
            writeCount += 1
        }

        operator fun get(key: String): String? = values[key]
    }

    private companion object {
        fun record(title: String): FinalCallRecord {
            return FinalCallRecord(
                title = title,
                status = "普通通话",
                meta = "刚刚",
                success = true,
                occurredAtMillis = title.hashCode().toLong()
            )
        }

        fun sourceFile(path: String): File {
            return listOf(
                File(path),
                File("android/app/$path")
            ).first { it.exists() }
        }
    }
}
