package com.vvtech.aiassistant.features.assistant_contacts

import com.vvtech.aiassistant.data.model.ContactDirectoryEntry
import com.vvtech.aiassistant.data.model.ContactDirectoryUpsertRequest

internal fun buildContactRemarkUpsertRequest(
    phone: String,
    fallbackDisplayName: String,
    existing: ContactDirectoryEntry?,
    remark: String
): ContactDirectoryUpsertRequest = ContactDirectoryUpsertRequest(
    userId = "",
    phone = normalizeAssistantContactPhoneKey(phone),
    displayName = existing?.displayName ?: fallbackDisplayName.trim().ifBlank { null },
    primaryRelation = existing?.primaryRelation,
    speakingStyle = existing?.speakingStyle,
    description = remark.trim().ifBlank { null }
)
