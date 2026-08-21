package com.vvtech.aiassistant.data.model

data class WorkIdentityItem(
    val company: String = "",
    val department: String = "",
    val position: String = ""
)

data class UserIdentityPayload(
    val userId: String? = null,
    val name: String? = null,
    val gender: String? = null,
    val contactPhone: String? = null,
    val workIdentities: List<WorkIdentityItem>? = null,
    val description: String? = null,
    val verificationStatus: String? = null,
    val verifiedAt: String? = null,
    val updatedAt: String? = null
)

data class UserIdentityUpsertRequest(
    val userId: String,
    val name: String?,
    val gender: String?,
    val contactPhone: String?,
    val workIdentities: List<WorkIdentityItem>?,
    val description: String?
)

data class UserIdentityVerifiedMetadataRequest(
    val userId: String,
    val gender: String?,
    val contactPhone: String?
)

data class ContactDirectoryEntry(
    val phone: String = "",
    val displayName: String? = null,
    val primaryRelation: String? = null,
    val speakingStyle: String? = null,
    val description: String? = null,
    val updatedAt: String? = null
)

data class ContactDirectoryUpsertRequest(
    val userId: String,
    val phone: String,
    val displayName: String?,
    val primaryRelation: String?,
    val speakingStyle: String?,
    val description: String?
)

data class ContactLookupResultRequest(
    val sessionId: String,
    val pendingToolCallId: String,
    val userId: String,
    val result: Map<String, Any?>,
    val languageCode: String? = null,
    val responseLanguage: String? = null
)

data class DeviceContactsLookupResultRequest(
    val sessionId: String,
    val pendingToolCallId: String,
    val userId: String,
    val results: List<Map<String, Any?>>,
    val channel: String? = null,
    val languageCode: String? = null,
    val responseLanguage: String? = null
)

data class ContactAiModelRequest(
    val userId: String,
    val callId: String
)
