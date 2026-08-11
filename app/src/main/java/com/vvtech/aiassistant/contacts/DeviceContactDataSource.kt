package com.vvtech.aiassistant.contacts

import android.content.Context
import android.database.Cursor
import android.provider.ContactsContract

internal data class DeviceContactPhoneRow(
    val contactId: String? = null,
    val displayName: String,
    val phoneNumber: String,
    val label: String? = null,
    val dialNumber: String = phoneNumber,
    val systemDialNumber: String = phoneNumber,
    val countryIso: String? = null,
    val dialCode: String? = null,
    val nationalNumber: String = phoneNumber.filter(Char::isDigit)
)

internal class DeviceContactDataSource(context: Context) {
    private val contentResolver = context.applicationContext.contentResolver

    fun loadPhoneRows(): List<DeviceContactPhoneRow> {
        return queryPhoneRows(
            selection = null,
            selectionArgs = null,
            sortOrder = "${PhoneColumns.DisplayName} COLLATE LOCALIZED ASC"
        )
    }

    fun findRowsByDisplayNameExact(displayName: String): List<DeviceContactPhoneRow> {
        return queryPhoneRows(
            selection = "${PhoneColumns.DisplayName} = ?",
            selectionArgs = arrayOf(displayName),
            sortOrder = null
        )
    }

    fun findRowsByDisplayNameLike(displayName: String): List<DeviceContactPhoneRow> {
        return queryPhoneRows(
            selection = "${PhoneColumns.DisplayName} LIKE ?",
            selectionArgs = arrayOf("%$displayName%"),
            sortOrder = null
        )
    }

    private fun queryPhoneRows(
        selection: String?,
        selectionArgs: Array<String>?,
        sortOrder: String?
    ): List<DeviceContactPhoneRow> {
        val rows = mutableListOf<DeviceContactPhoneRow>()
        contentResolver.query(
            PhoneColumns.ContentUri,
            Projection,
            selection,
            selectionArgs,
            sortOrder
        )?.use { cursor ->
            val contactIdIndex = cursor.getColumnIndex(PhoneColumns.ContactId)
            val nameIndex = cursor.getColumnIndex(PhoneColumns.DisplayName)
            val numberIndex = cursor.getColumnIndex(PhoneColumns.Number)
            val normalizedNumberIndex = cursor.getColumnIndex(PhoneColumns.NormalizedNumber)
            val labelIndex = cursor.getColumnIndex(PhoneColumns.Label)
            while (cursor.moveToNext()) {
                val rawNumber = cursor.getStringOrEmpty(numberIndex)
                val phoneValue = DeviceContactPhoneCountryPolicy.resolve(
                    rawNumber = rawNumber,
                    normalizedNumber = cursor.getOptionalString(normalizedNumberIndex)
                ) ?: continue

                rows += DeviceContactPhoneRow(
                    contactId = cursor.getOptionalString(contactIdIndex),
                    displayName = cursor.getStringOrEmpty(nameIndex),
                    phoneNumber = phoneValue.lookupNumber,
                    label = cursor.getOptionalString(labelIndex),
                    dialNumber = phoneValue.dialNumber,
                    systemDialNumber = rawNumber.ifBlank { phoneValue.lookupNumber },
                    countryIso = phoneValue.countryIso,
                    dialCode = phoneValue.dialCode,
                    nationalNumber = phoneValue.nationalNumber
                )
            }
        }
        return rows
    }

    private companion object {
        private val Projection = arrayOf(
            PhoneColumns.ContactId,
            PhoneColumns.DisplayName,
            PhoneColumns.Number,
            PhoneColumns.NormalizedNumber,
            PhoneColumns.Label
        )
    }

    private object PhoneColumns {
        val ContentUri = ContactsContract.CommonDataKinds.Phone.CONTENT_URI
        val ContactId = ContactsContract.CommonDataKinds.Phone.CONTACT_ID
        val DisplayName = ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME
        val Number = ContactsContract.CommonDataKinds.Phone.NUMBER
        val NormalizedNumber = ContactsContract.CommonDataKinds.Phone.NORMALIZED_NUMBER
        val Label = ContactsContract.CommonDataKinds.Phone.LABEL
    }
}

private fun Cursor.getStringOrEmpty(index: Int): String {
    if (index < 0) return ""
    return getString(index)?.trim().orEmpty()
}

private fun Cursor.getOptionalString(index: Int): String? {
    return getStringOrEmpty(index).takeIf { it.isNotBlank() }
}
