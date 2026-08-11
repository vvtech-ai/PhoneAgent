package com.vvtech.aiassistant.features.assistant_contacts

import android.widget.Toast
import androidx.core.content.ContextCompat
import com.vvtech.aiassistant.account.AccountIdentityProvider
import com.vvtech.aiassistant.contacts.DeviceContactResolver
import com.vvtech.aiassistant.data.model.ContactDirectoryUpsertRequest
import com.vvtech.aiassistant.devhook.DevMockHooks
import com.vvtech.aiassistant.features.assistant.AssistantContactRuntimeCallbacks
import com.vvtech.aiassistant.features.assistant.AssistantContactRuntimeDeps
import com.vvtech.aiassistant.features.assistant.AssistantContactRuntimeState
import com.vvtech.aiassistant.features.assistant.FinalPage
import com.vvtech.aiassistant.features.assistant.mapDeviceContactsToFinalRecords
import com.vvtech.aiassistant.logging.RuntimeStateLogDomain
import com.vvtech.aiassistant.logging.RuntimeStateLogEvent
import com.vvtech.aiassistant.logging.RuntimeStateLogger
import kotlinx.coroutines.launch

internal class AssistantContactDirectoryRuntimeController(
    private val state: AssistantContactRuntimeState,
    private val deps: AssistantContactRuntimeDeps,
    callbacks: AssistantContactRuntimeCallbacks
) {
    private var callbacks = callbacks

    fun updateCallbacks(callbacks: AssistantContactRuntimeCallbacks) {
        this.callbacks = callbacks
    }

    fun refreshDeviceContacts(onComplete: (() -> Unit)? = null) {
        logContact("DEVICE_CONTACT_REFRESH_STARTED", "started", "refresh_requested")
        deps.scope.launch {
            val hasSystemPermission = DevMockHooks.bypassContactsPermission() ||
                ContextCompat.checkSelfPermission(
                    deps.context,
                    android.Manifest.permission.READ_CONTACTS
                ) == android.content.pm.PackageManager.PERMISSION_GRANTED
            callbacks.onContactsPermissionGrantedChange(hasSystemPermission)
            if (!hasSystemPermission) {
                logContact(
                    "DEVICE_CONTACT_REFRESH_BLOCKED",
                    "blocked",
                    "missing_read_contacts_permission"
                )
                onComplete?.invoke()
                return@launch
            }

            runCatching {
                DeviceContactResolver(deps.context).loadPhoneContacts()
            }.map { contacts ->
                mapDeviceContactsToFinalRecords(contacts)
            }.onSuccess { records ->
                state.contactRecords.clear()
                state.contactRecords.addAll(records)
                logContact(
                    "DEVICE_CONTACT_REFRESH_COMPLETED",
                    "completed",
                    "contacts_loaded",
                    mapOf("recordCount" to records.size.toString())
                )
            }.onFailure { throwable ->
                logContact(
                    "DEVICE_CONTACT_REFRESH_FAILED",
                    "failed",
                    "device_contact_load_failure",
                    throwable = throwable
                )
                Toast.makeText(
                    deps.context,
                    throwable.message ?: "读取本机联系人失败",
                    Toast.LENGTH_SHORT
                ).show()
            }.also {
                onComplete?.invoke()
            }
        }
    }

    fun refreshContactDirectory() {
        val userId = AccountIdentityProvider.accountId
        if (userId.isBlank()) {
            logContact("CONTACT_DIRECTORY_REFRESH_SKIPPED", "skipped", "missing_account")
            return
        }
        logContact("CONTACT_DIRECTORY_REFRESH_STARTED", "started", "refresh_requested")
        deps.scope.launch {
            state.contactDirectoryLoading.value = true
            state.contactDirectoryError.value = null
            runCatching { deps.repository.listContacts(userId) }
                .onSuccess {
                    state.contactDirectoryEntries.value = it
                    state.contactDirectoryLoading.value = false
                    logContact(
                        "CONTACT_DIRECTORY_REFRESH_COMPLETED",
                        "completed",
                        "directory_loaded",
                        mapOf("recordCount" to it.size.toString())
                    )
                }
                .onFailure { throwable ->
                    state.contactDirectoryLoading.value = false
                    state.contactDirectoryError.value = throwable.message ?: "联系人备注加载失败"
                    logContact(
                        "CONTACT_DIRECTORY_REFRESH_FAILED",
                        "failed",
                        "directory_load_failure",
                        throwable = throwable
                    )
                }
        }
    }

    fun saveContactDirectoryEntry(request: ContactDirectoryUpsertRequest) {
        val userId = AccountIdentityProvider.accountId
        if (userId.isBlank() || request.phone.isBlank()) {
            logContact(
                "CONTACT_DIRECTORY_SAVE_SKIPPED",
                "skipped",
                if (userId.isBlank()) "missing_account" else "missing_phone"
            )
            return
        }
        logContact("CONTACT_DIRECTORY_SAVE_STARTED", "started", "save_requested")
        state.directoryDetailSaving.value = true
        state.directoryDetailError.value = null
        deps.scope.launch {
            runCatching {
                deps.repository.upsertContact(request.copy(userId = userId))
            }.onSuccess { entry ->
                val updated = state.contactDirectoryEntries.value.toMutableList()
                val key = normalizeAssistantContactPhoneKey(entry.phone)
                val idx = updated.indexOfFirst { normalizeAssistantContactPhoneKey(it.phone) == key }
                if (idx >= 0) updated[idx] = entry else updated.add(entry)
                state.contactDirectoryEntries.value = updated
                state.directoryDetailSaving.value = false
                Toast.makeText(deps.context, "已保存联系人备注", Toast.LENGTH_SHORT).show()
                logContact("CONTACT_DIRECTORY_SAVE_COMPLETED", "completed", "entry_saved")
            }.onFailure { throwable ->
                state.directoryDetailSaving.value = false
                state.directoryDetailError.value = throwable.message ?: "保存失败"
                logContact(
                    "CONTACT_DIRECTORY_SAVE_FAILED",
                    "failed",
                    "entry_save_failure",
                    throwable = throwable
                )
            }
        }
    }

    fun deleteContactDirectoryEntry(phone: String) {
        val userId = AccountIdentityProvider.accountId
        if (userId.isBlank() || phone.isBlank()) {
            logContact(
                "CONTACT_DIRECTORY_DELETE_SKIPPED",
                "skipped",
                if (userId.isBlank()) "missing_account" else "missing_phone"
            )
            return
        }
        logContact("CONTACT_DIRECTORY_DELETE_STARTED", "started", "delete_requested")
        deps.scope.launch {
            runCatching { deps.repository.deleteContact(phone, userId) }
                .onSuccess {
                    val key = normalizeAssistantContactPhoneKey(phone)
                    state.contactDirectoryEntries.value = state.contactDirectoryEntries.value.filterNot {
                        normalizeAssistantContactPhoneKey(it.phone) == key
                    }
                    Toast.makeText(deps.context, "已删除联系人备注", Toast.LENGTH_SHORT).show()
                    callbacks.onPageChange(FinalPage.Contacts)
                    logContact("CONTACT_DIRECTORY_DELETE_COMPLETED", "completed", "entry_deleted")
                }
                .onFailure { throwable ->
                    state.directoryDetailError.value = throwable.message ?: "删除失败"
                    logContact(
                        "CONTACT_DIRECTORY_DELETE_FAILED",
                        "failed",
                        "entry_delete_failure",
                        throwable = throwable
                    )
                }
        }
    }

    private fun logContact(
        eventType: String,
        result: String,
        reason: String,
        attributes: Map<String, String?> = emptyMap(),
        throwable: Throwable? = null
    ) {
        val event = RuntimeStateLogEvent(
            domain = RuntimeStateLogDomain.CONTACT,
            eventType = eventType,
            result = result,
            reason = reason,
            attributes = attributes + ("exceptionType" to throwable?.javaClass?.simpleName)
        )
        if (throwable == null) RuntimeStateLogger.info(event) else RuntimeStateLogger.warn(event, throwable)
    }
}
