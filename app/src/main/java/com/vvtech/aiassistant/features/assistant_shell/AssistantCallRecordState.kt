package com.vvtech.aiassistant.features.assistant_shell

import android.content.SharedPreferences
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.vvtech.aiassistant.features.assistant.FinalCallRecord
import com.vvtech.aiassistant.features.assistant.DialCallKind
import com.vvtech.aiassistant.features.assistant.decodeFinalCallRecords
import com.vvtech.aiassistant.features.assistant.encodeFinalCallRecords
import com.vvtech.aiassistant.features.assistant.finalCallRecordsStorageKey

internal interface AssistantCallRecordStore {
    fun getString(key: String): String?
    fun putString(key: String, value: String)
}

internal class SharedPreferencesAssistantCallRecordStore(
    private val prefs: SharedPreferences
) : AssistantCallRecordStore {
    override fun getString(key: String): String? = prefs.getString(key, null)

    override fun putString(key: String, value: String) {
        prefs.edit().putString(key, value).apply()
    }
}

internal class AssistantCallRecordState(
    private val store: AssistantCallRecordStore
) {
    private val mutableRecords = mutableStateListOf<FinalCallRecord>()
    private var selectedRecordState by mutableStateOf<FinalCallRecord?>(null)

    val records: List<FinalCallRecord>
        get() = mutableRecords.toList()

    val selectedRecord: FinalCallRecord?
        get() = selectedRecordState

    fun latestRecord(): FinalCallRecord? = mutableRecords.firstOrNull()

    fun loadForAccount(accountId: String) {
        mutableRecords.clear()
        if (accountId.isBlank()) return
        mutableRecords.addAll(
            decodeFinalCallRecords(
                store.getString(finalCallRecordsStorageKey(accountId))
            )
        )
    }

    fun clearForAccount(accountId: String, persist: Boolean = true) {
        mutableRecords.clear()
        if (persist && accountId.isNotBlank()) {
            persistForAccount(accountId)
        }
    }

    fun appendForAccount(accountId: String, record: FinalCallRecord) {
        mutableRecords.add(0, record)
        persistForAccount(accountId)
    }

    fun appendIfAbsentForAccount(accountId: String, record: FinalCallRecord): Boolean {
        val callId = record.callId.trim()
        if (callId.isNotBlank() && mutableRecords.any {
                it.callId == callId && it.callKind == record.callKind
            }
        ) {
            return false
        }
        appendForAccount(accountId, record)
        return true
    }

    fun selectRecord(record: FinalCallRecord) {
        selectedRecordState = record
    }

    fun clearSelectedRecord() {
        selectedRecordState = null
    }

    fun persistForAccount(accountId: String) {
        if (accountId.isBlank()) return
        store.putString(
            finalCallRecordsStorageKey(accountId),
            encodeFinalCallRecords(mutableRecords.toList())
        )
    }
}

@Composable
internal fun rememberAssistantCallRecordState(
    prefs: SharedPreferences
): AssistantCallRecordState {
    val store = remember(prefs) { SharedPreferencesAssistantCallRecordStore(prefs) }
    return remember(store) { AssistantCallRecordState(store) }
}
