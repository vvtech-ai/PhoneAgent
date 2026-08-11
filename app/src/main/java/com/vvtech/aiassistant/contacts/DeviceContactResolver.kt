package com.vvtech.aiassistant.contacts

import android.content.Context
import com.vvtech.aiassistant.devhook.DevMockHooks
import com.vvtech.aiassistant.features.assistant.DevicePhoneContact
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

data class CallContactCandidate(
    val contactName: String
)

data class ExplicitContactInfo(
    val contactName: String,
    val phoneNumber: String
)

data class ContactLookupResult(
    val contactName: String,
    val phoneNumber: String? = null,
    val found: Boolean = false
)

data class ContactLookupCandidateResult(
    val contactName: String,
    val phoneNumber: String? = null,
    val status: String
)

data class PhoneLookupResult(
    val phoneNumber: String,
    val displayName: String? = null,
    val note: String? = null,
    val found: Boolean = false
)

data class DeviceContactPhoneCandidate(
    val contactId: String? = null,
    val displayName: String,
    val phoneNumber: String,
    val label: String? = null
)

data class DeviceContactsLookupItem(
    val name: String,
    val status: String,
    val candidates: List<DeviceContactPhoneCandidate> = emptyList(),
    val matchType: String? = null
)

/**
 * Lightweight contact lookup for AI call requests.
 */
class DeviceContactResolver(
    context: Context
) {

    private val dataSource = DeviceContactDataSource(context)
    private val contactNameNormalizer = DeviceContactNameNormalizer()
    private val candidateLookupUseCase = DeviceContactCandidateLookupUseCase(
        dataSource = dataSource,
        pinyinEntriesProvider = ::loadPinyinEntriesIfNeeded,
        typedNameNormalizer = contactNameNormalizer::normalize
    )

    private fun loadPinyinEntriesIfNeeded(): List<PinyinContactEntry> {
        cachedPinyinContactEntries().takeIf { it.isNotEmpty() }?.let { return it }
        return dataSource.loadPhoneRows()
            .asSequence()
            .filter { it.displayName.isNotBlank() }
            .map { row ->
                PinyinContactEntry(
                    contactId = row.contactId,
                    displayName = row.displayName,
                    phoneNumber = row.phoneNumber,
                    label = row.label,
                    namePinyin = ContactPinyinTokenizer.toPinyinTokens(
                        contactNameNormalizer.normalize(row.displayName)
                    )
                )
            }
            .filter { it.namePinyin.isNotEmpty() }
            .distinctBy { it.displayName to it.phoneNumber }
            .toList()
            .also(::replacePinyinIndex)
    }

    internal suspend fun loadPhoneContacts(): List<DevicePhoneContact> = withContext(Dispatchers.IO) {
        DevMockHooks.mockLoadAllContacts()?.let { return@withContext it }
        val contacts = linkedMapOf<String, DevicePhoneContact>()
        val pinyinEntries = linkedMapOf<String, PinyinContactEntry>()

        dataSource.loadPhoneRows().forEach { row ->
            val normalizedName = row.displayName.ifBlank { "未知联系人" }
            val dedupeKey = "$normalizedName\u0000${row.phoneNumber}"
            if (!contacts.containsKey(dedupeKey)) {
                contacts[dedupeKey] = DevicePhoneContact(
                    name = normalizedName,
                    phone = row.phoneNumber,
                    systemDialPhone = row.systemDialNumber
                )
            }
            if (row.displayName.isNotBlank() && !pinyinEntries.containsKey(dedupeKey)) {
                val entry = PinyinContactEntry(
                    contactId = row.contactId,
                    displayName = row.displayName,
                    phoneNumber = row.phoneNumber,
                    label = row.label,
                    namePinyin = ContactPinyinTokenizer.toPinyinTokens(
                        contactNameNormalizer.normalize(row.displayName)
                    )
                )
                if (entry.namePinyin.isNotEmpty()) {
                    pinyinEntries[dedupeKey] = entry
                }
            }
        }

        replacePinyinIndex(pinyinEntries.values.toList())
        contacts.values.toList()
    }

    suspend fun findPhoneByDisplayName(contactName: String): ContactLookupResult = withContext(Dispatchers.IO) {
        val normalizedName = contactName.trim()
        if (normalizedName.isBlank()) {
            return@withContext ContactLookupResult(contactName = normalizedName, phoneNumber = null, found = false)
        }

        findFirstPhoneByName(dataSource.findRowsByDisplayNameExact(normalizedName), normalizedName)?.let {
            return@withContext it
        }
        findFirstPhoneByName(dataSource.findRowsByDisplayNameLike(normalizedName), normalizedName)?.let {
            return@withContext it
        }

        ContactLookupResult(contactName = normalizedName, phoneNumber = null, found = false)
    }

    private fun findFirstPhoneByName(
        rows: List<DeviceContactPhoneRow>,
        fallbackName: String
    ): ContactLookupResult? {
        val row = rows.firstOrNull { it.phoneNumber.isNotBlank() } ?: return null
        return ContactLookupResult(
            contactName = row.displayName.ifBlank { fallbackName },
            phoneNumber = row.phoneNumber,
            found = true
        )
    }

    suspend fun findExactPhonesByDisplayNames(contactNames: List<String>): List<ContactLookupCandidateResult> =
        withContext(Dispatchers.IO) {
            contactNames
                .map { it.trim() }
                .filter { it.isNotBlank() }
                .distinct()
                .map { name -> findExactPhoneByDisplayName(name) }
        }

    private fun findExactPhoneByDisplayName(contactName: String): ContactLookupCandidateResult {
        val phones = dataSource.findRowsByDisplayNameExact(contactName)
            .mapTo(linkedSetOf<String>()) { it.phoneNumber }
        return when (phones.size) {
            1 -> ContactLookupCandidateResult(contactName, phones.first(), "FOUND")
            0 -> ContactLookupCandidateResult(contactName, null, "NOT_FOUND")
            else -> ContactLookupCandidateResult(contactName, null, "AMBIGUOUS")
        }
    }

    suspend fun findCandidatesByDisplayNames(
        contactNames: List<String>,
        allowFuzzyMatching: Boolean
    ): List<DeviceContactsLookupItem> = withContext(Dispatchers.IO) {
        candidateLookupUseCase.findCandidatesByDisplayNames(contactNames, allowFuzzyMatching)
    }

    fun invalidateCandidatesCache() {
        candidateLookupUseCase.clearCache()
        clearPinyinIndex()
    }

    suspend fun findByPhone(phone: String): PhoneLookupResult = withContext(Dispatchers.IO) {
        val rawQuery = phone.trim()
        if (rawQuery.isBlank()) {
            return@withContext PhoneLookupResult(phoneNumber = rawQuery, found = false)
        }
        val targetDigits = rawQuery.filter(Char::isDigit)
        if (targetDigits.isBlank()) {
            return@withContext PhoneLookupResult(phoneNumber = rawQuery, found = false)
        }

        DevMockHooks.mockFindContactByPhone(rawQuery)?.let { return@withContext it }

        dataSource.loadPhoneRows().forEach { row ->
            val digits = row.phoneNumber.filter(Char::isDigit)
            if (digits.isBlank()) return@forEach
            val matched = digits.endsWith(targetDigits) || targetDigits.endsWith(digits)
            if (!matched) return@forEach
            val matchedName = row.displayName.ifBlank { null }
            return@withContext PhoneLookupResult(
                phoneNumber = rawQuery,
                displayName = matchedName,
                note = row.label,
                found = matchedName != null
            )
        }

        PhoneLookupResult(phoneNumber = rawQuery, found = false)
    }

    companion object {
        @Volatile private var pinyinIndex: List<PinyinContactEntry> = emptyList()

        private fun replacePinyinIndex(entries: List<PinyinContactEntry>) {
            pinyinIndex = entries
        }

        private fun clearPinyinIndex() {
            pinyinIndex = emptyList()
        }

        private fun cachedPinyinContactEntries(): List<PinyinContactEntry> = pinyinIndex

        internal fun normalizeDeviceContactPhone(raw: String): String = DeviceContactPolicy.normalizePhone(raw)

        fun extractCallContactCandidate(message: String): CallContactCandidate? =
            DeviceContactPolicy.extractCallContactCandidate(message)

        fun extractCallContactCandidateNames(message: String): List<String> =
            DeviceContactPolicy.extractCallContactCandidateNames(message)

        fun extractExplicitContact(message: String): ExplicitContactInfo? =
            DeviceContactPolicy.extractExplicitContact(message)

        fun containsPhone(message: String): Boolean = DeviceContactPolicy.containsPhone(message)
    }
}
