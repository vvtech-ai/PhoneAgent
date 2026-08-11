package com.vvtech.aiassistant.features.assistant_calls

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.core.content.ContextCompat
import com.vvtech.aiassistant.contacts.ContactPinyinTokenizer
import com.vvtech.aiassistant.contacts.DeviceContactDataSource
import com.vvtech.aiassistant.contacts.DeviceContactPhoneRow
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

internal data class DialContactDirectoryState(
    val contacts: List<DialContactEntry> = emptyList(),
    val permissionGranted: Boolean = false,
    val loaded: Boolean = false
)

@Composable
internal fun rememberDialContactDirectoryState(): DialContactDirectoryState {
    val context = LocalContext.current.applicationContext
    val permissionGranted = context.hasContactReadPermission()
    var state by remember { mutableStateOf(DialContactDirectoryState()) }

    LaunchedEffect(context, permissionGranted) {
        state = if (!permissionGranted) {
            DialContactDirectoryState(permissionGranted = false, loaded = true)
        } else {
            val contacts = withContext(Dispatchers.IO) {
                loadDialContacts(context)
            }
            DialContactDirectoryState(
                contacts = contacts,
                permissionGranted = true,
                loaded = true
            )
        }
    }
    return state
}

private fun loadDialContacts(context: Context): List<DialContactEntry> = runCatching {
    DeviceContactDataSource(context).loadPhoneRows().map { it.toDialContactEntry() }
}.getOrDefault(emptyList())

internal fun DeviceContactPhoneRow.toDialContactEntry() =
    DialContactEntry(
        contactId = contactId,
        displayName = displayName.ifBlank { phoneNumber },
        phoneNumber = dialNumber,
        pinyinTokens = ContactPinyinTokenizer.toPinyinTokens(displayName)
    )

private fun Context.hasContactReadPermission(): Boolean =
    ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CONTACTS) ==
        PackageManager.PERMISSION_GRANTED
