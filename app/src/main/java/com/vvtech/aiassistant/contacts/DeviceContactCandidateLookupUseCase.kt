package com.vvtech.aiassistant.contacts

import com.vvtech.aiassistant.devhook.DevMockHooks
import java.util.Locale

internal class DeviceContactCandidateLookupUseCase(
    private val dataSource: DeviceContactDataSource,
    private val pinyinEntriesProvider: () -> List<PinyinContactEntry>,
    private val typedNameNormalizer: (String) -> String,
    private val clock: () -> Long = System::currentTimeMillis
) {
    private val candidatesCache: MutableMap<String, CandidatesCacheEntry> = LinkedHashMap()

    fun findCandidatesByDisplayNames(
        contactNames: List<String>,
        allowFuzzyMatching: Boolean
    ): List<DeviceContactsLookupItem> {
        val normalizedNames = contactNames
            .map { it.trim() }
            .filter { it.isNotBlank() }
            .distinct()
        if (normalizedNames.isEmpty()) return emptyList()

        val now = clock()
        val cacheSnapshot = synchronized(candidatesCache) {
            evictExpiredCandidatesLocked(now)
            normalizedNames.associateWith { name ->
                candidatesCache[cacheKey(name, allowFuzzyMatching)]
                    ?.takeIf { entry -> entry.isFresh(now) }
                    ?.value
            }
        }
        val missing = normalizedNames.filter { cacheSnapshot[it] == null }

        val freshlyResolved: Map<String, DeviceContactsLookupItem> = if (missing.isEmpty()) {
            emptyMap()
        } else {
            val resolved = mutableMapOf<String, DeviceContactsLookupItem>()
            // ponytail: scan once for deterministic typed matching; index only if large contact books make this slow.
            val typedRows = if (allowFuzzyMatching) emptyList() else dataSource.loadPhoneRows()
            missing.forEach { name ->
                resolved[name] = lookupCandidatesForName(name, allowFuzzyMatching, typedRows)
            }
            synchronized(candidatesCache) {
                resolved.forEach { (name, item) ->
                    candidatesCache[cacheKey(name, allowFuzzyMatching)] = CandidatesCacheEntry(item, now)
                }
            }
            resolved
        }

        return normalizedNames.map { name ->
            cacheSnapshot[name] ?: freshlyResolved[name] ?: DeviceContactsLookupItem(
                name = name,
                status = "NOT_FOUND"
            )
        }
    }

    fun clearCache() {
        synchronized(candidatesCache) { candidatesCache.clear() }
    }

    private fun lookupCandidatesForName(
        contactName: String,
        allowFuzzyMatching: Boolean,
        typedRows: List<DeviceContactPhoneRow>
    ): DeviceContactsLookupItem {
        DevMockHooks.mockLookupCandidatesByName(contactName)?.let { return it }

        val candidates = linkedMapOf<String, DeviceContactPhoneCandidate>()
        var matchType: String? = null

        fun addCandidate(row: DeviceContactPhoneRow) {
            val key = typedNameNormalizer(row.displayName).lowercase(Locale.ROOT) +
                "\u0000" + row.phoneNumber.trim()
            if (!candidates.containsKey(key)) {
                candidates[key] = DeviceContactPhoneCandidate(
                    contactId = row.contactId,
                    displayName = row.displayName.ifBlank { contactName },
                    phoneNumber = row.phoneNumber,
                    label = row.label
                )
            }
        }

        if (allowFuzzyMatching) {
            dataSource.findRowsByDisplayNameExact(contactName).forEach(::addCandidate)
            if (candidates.isNotEmpty()) {
                matchType = "name_exact"
            }
            if (candidates.isEmpty()) {
                dataSource.findRowsByDisplayNameLike(contactName).forEach(::addCandidate)
                if (candidates.isNotEmpty()) {
                    matchType = "name_like"
                }
            }
            val candidatesBeforePinyin = candidates.size
            runPinyinFallbackQuery(contactName).forEach { result ->
                addCandidate(result.entry.toPhoneRow())
            }
            if (candidates.size > candidatesBeforePinyin) {
                matchType = if (candidatesBeforePinyin == 0) {
                    "pinyin_fallback"
                } else {
                    "${matchType}_with_pinyin_candidates"
                }
            }
        } else {
            typedRows
                .filter { row -> typedContactNamesMatch(contactName, row.displayName, typedNameNormalizer) }
                .forEach(::addCandidate)
            if (candidates.isNotEmpty()) matchType = "name_exact"
        }

        val list = candidates.values.toList()
        val status = resolveDeviceContactLookupStatus(
            candidateCount = list.size,
            matchType = matchType
        )
        return DeviceContactsLookupItem(
            name = contactName,
            status = status,
            candidates = list,
            matchType = matchType
        )
    }

    private fun runPinyinFallbackQuery(contactName: String): List<PinyinSearchResult> {
        val contacts = pinyinEntriesProvider()
        if (contacts.isEmpty()) return emptyList()
        return ContactPinyinSearchEngine().search(contactName, contacts)
    }

    private fun cacheKey(contactName: String, allowFuzzyMatching: Boolean): String {
        return "${if (allowFuzzyMatching) 'f' else 'e'}\u0000$contactName"
    }

    private fun PinyinContactEntry.toPhoneRow(): DeviceContactPhoneRow {
        return DeviceContactPhoneRow(
            contactId = contactId,
            displayName = displayName,
            phoneNumber = phoneNumber,
            label = label
        )
    }

    private data class CandidatesCacheEntry(
        val value: DeviceContactsLookupItem,
        val timestampMs: Long
    ) {
        fun isFresh(now: Long): Boolean = now - timestampMs < CACHE_TTL_MS
    }

    private fun evictExpiredCandidatesLocked(now: Long) {
        val iterator = candidatesCache.entries.iterator()
        while (iterator.hasNext()) {
            val entry = iterator.next()
            if (!entry.value.isFresh(now)) iterator.remove()
        }
    }

    private companion object {
        private const val CACHE_TTL_MS: Long = 30_000L
    }
}

internal fun resolveDeviceContactLookupStatus(candidateCount: Int, matchType: String?): String {
    return when {
        candidateCount == 0 -> "NOT_FOUND"
        matchType == "pinyin_fallback" -> "MULTIPLE_CANDIDATES"
        candidateCount == 1 -> "RESOLVED"
        else -> "MULTIPLE_CANDIDATES"
    }
}
