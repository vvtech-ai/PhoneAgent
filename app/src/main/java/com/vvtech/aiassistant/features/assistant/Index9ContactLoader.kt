package com.vvtech.aiassistant.features.assistant

import android.content.Context
import android.content.pm.PackageManager
import android.widget.Toast
import androidx.core.content.ContextCompat
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

internal fun refreshFinalDeviceContacts(
    context: Context,
    scope: CoroutineScope,
    assistantViewModel: AssistantViewModel,
    contactRecords: MutableList<FinalContactRecord>,
    updatePermissionGranted: (Boolean) -> Unit
) {
    scope.launch {
        val hasSystemPermission = ContextCompat.checkSelfPermission(
            context,
            android.Manifest.permission.READ_CONTACTS
        ) == PackageManager.PERMISSION_GRANTED
        updatePermissionGranted(hasSystemPermission)
        if (!hasSystemPermission) {
            assistantViewModel.clearSystemDeviceContactsCache()
            return@launch
        }

        runCatching {
            assistantViewModel.loadSystemDeviceContactsForUi()
        }.onSuccess { contacts ->
            contactRecords.clear()
            contactRecords.addAll(mapDeviceContactsToFinalRecords(contacts))
        }.onFailure { throwable ->
            assistantViewModel.clearSystemDeviceContactsCache()
            Toast.makeText(
                context,
                throwable.message ?: currentAppText("读取本机联系人失败", "Failed to read device contacts"),
                Toast.LENGTH_SHORT
            ).show()
        }
    }
}
