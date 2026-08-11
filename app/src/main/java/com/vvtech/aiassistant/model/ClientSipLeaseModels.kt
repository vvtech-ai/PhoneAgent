package com.vvtech.aiassistant.model

data class ClientSipLeaseRequest(
    val route: String = "local",
    val purpose: String = "local_sip_call",
    val callId: String? = null,
    val deviceId: String? = null
)

data class ClientSipLeaseResponse(
    val leaseId: String,
    val sipAccountId: String,
    val server: String,
    val port: Int,
    val transport: String,
    val username: String,
    val password: String,
    val callerNumber: String,
    val expiresAt: String? = null
)

data class ClientSipLeaseReleaseRequest(
    val reason: String? = null,
    val callId: String? = null,
    val deviceId: String? = null
)

data class ClientSipLeaseReleaseResponse(
    val leaseId: String,
    val released: Boolean
)
