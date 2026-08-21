package com.vvtech.aiassistant.features.assistant

import android.content.Context
import android.widget.Toast
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.core.content.ContextCompat
import com.vvtech.aiassistant.contacts.DeviceContactsLookupItem
import com.vvtech.aiassistant.contacts.DeviceContactResolver
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

internal class AssistantAgentLookupContactEffectArgs(
    val context: Context,
    val assistantUiState: Index9AssistantUiState,
    val agentContactsPermissionRetry: Int,
    val contactsPermissionGranted: Boolean,
    val onContactsPermissionGrantedChange: (Boolean) -> Unit,
    val agentContactsPermissionAskedKey: String?,
    val onAgentContactsPermissionAskedKeyChange: (String?) -> Unit,
    val onLaunchContactsPermission: (String) -> Unit,
    val scope: CoroutineScope,
    val deviceContactResolver: DeviceContactResolver,
    val onAgentLookupContactResult: (Map<String, Any?>) -> Unit
)

internal class AssistantAgentLookupDeviceContactsEffectArgs(
    val context: Context,
    val assistantUiState: Index9AssistantUiState,
    val agentContactsPermissionRetry: Int,
    val contactsPermissionGranted: Boolean,
    val onContactsPermissionGrantedChange: (Boolean) -> Unit,
    val agentContactsPermissionAskedKey: String?,
    val onAgentContactsPermissionAskedKeyChange: (String?) -> Unit,
    val onLaunchContactsPermission: (String) -> Unit,
    val scope: CoroutineScope,
    val deviceContactResolver: DeviceContactResolver,
    val onAgentLookupDeviceContactsResolved: (
        results: List<Map<String, Any?>>,
        echoText: String?,
        pendingSelection: DeviceContactSelectionUiState?
    ) -> Unit
)

@Composable
internal fun FinalAgentLookupContactEffect(args: AssistantAgentLookupContactEffectArgs) {
    LaunchedEffect(args.assistantUiState.agentLookupContactInFlight, args.agentContactsPermissionRetry) {
        val phone = args.assistantUiState.agentLookupContactPhone.orEmpty()
        if (!args.assistantUiState.agentLookupContactInFlight || phone.isBlank()) {
            return@LaunchedEffect
        }
        val hasContactsPermission = ContextCompat.checkSelfPermission(
            args.context,
            android.Manifest.permission.READ_CONTACTS
        ) == android.content.pm.PackageManager.PERMISSION_GRANTED
        if (args.contactsPermissionGranted != hasContactsPermission) {
            args.onContactsPermissionGrantedChange(hasContactsPermission)
        }
        if (!hasContactsPermission) {
            val askKey = "lookupContact:$phone"
            if (args.agentContactsPermissionAskedKey != askKey) {
                args.onAgentContactsPermissionAskedKeyChange(askKey)
                args.onLaunchContactsPermission(android.Manifest.permission.READ_CONTACTS)
                return@LaunchedEffect
            }
            args.onAgentContactsPermissionAskedKeyChange(null)
            args.onAgentLookupContactResult(
                mapOf(
                    "found" to false,
                    "reason" to "PERMISSION_DENIED"
                )
            )
            Toast.makeText(args.context, currentAppText("未授权通讯录，AI 将另询用户", "Contacts permission denied. AI will ask the user instead"), Toast.LENGTH_SHORT).show()
            return@LaunchedEffect
        }
        args.onAgentContactsPermissionAskedKeyChange(null)
        args.scope.launch {
            runCatching {
                args.deviceContactResolver.findByPhone(phone)
            }.onSuccess { result ->
                if (result.found) {
                    val payload = buildMap<String, Any?> {
                        put("found", true)
                        put("source", "device")
                        result.displayName?.takeIf { it.isNotBlank() }?.let { put("displayName", it) }
                        result.note?.takeIf { it.isNotBlank() }?.let { put("note", it) }
                    }
                    args.onAgentLookupContactResult(payload)
                } else {
                    args.onAgentLookupContactResult(mapOf("found" to false))
                }
            }.onFailure {
                args.onAgentLookupContactResult(
                    mapOf("found" to false, "reason" to "DEVICE_LOOKUP_FAILED")
                )
            }
        }
    }
}

@Composable
internal fun FinalAgentLookupDeviceContactsEffect(args: AssistantAgentLookupDeviceContactsEffectArgs) {
    LaunchedEffect(args.assistantUiState.agentLookupDeviceContactsInFlight, args.agentContactsPermissionRetry) {
        val request = args.assistantUiState.agentLookupDeviceContactsRequest
        if (!args.assistantUiState.agentLookupDeviceContactsInFlight || request == null || request.names.isEmpty()) {
            return@LaunchedEffect
        }
        val hasContactsPermission = ContextCompat.checkSelfPermission(
            args.context,
            android.Manifest.permission.READ_CONTACTS
        ) == android.content.pm.PackageManager.PERMISSION_GRANTED
        if (args.contactsPermissionGranted != hasContactsPermission) {
            args.onContactsPermissionGrantedChange(hasContactsPermission)
        }
        if (!hasContactsPermission) {
            val askKey = "lookupDeviceContactsByNames:" + request.names.joinToString("|")
            if (args.agentContactsPermissionAskedKey != askKey) {
                args.onAgentContactsPermissionAskedKeyChange(askKey)
                args.onLaunchContactsPermission(android.Manifest.permission.READ_CONTACTS)
                return@LaunchedEffect
            }
            args.onAgentContactsPermissionAskedKeyChange(null)
            args.onAgentLookupDeviceContactsResolved(
                request.names.map { name ->
                    mapOf(
                        "name" to name,
                        "status" to "PERMISSION_DENIED",
                        "inputSource" to args.assistantUiState.agentContactInputSource.wireValue
                    )
                },
                currentAppText("未授权读取通讯录", "Contacts permission denied"),
                null
            )
            Toast.makeText(args.context, currentAppText("未授权通讯录，AI 将另询用户", "Contacts permission denied. AI will ask the user instead"), Toast.LENGTH_SHORT).show()
            return@LaunchedEffect
        }
        args.onAgentContactsPermissionAskedKeyChange(null)
        val inputSource = args.assistantUiState.agentContactInputSource
        args.scope.launch {
            runCatching {
                args.deviceContactResolver.findCandidatesByDisplayNames(
                    contactNames = request.names,
                    allowFuzzyMatching = inputSource == AgentContactInputSource.ASR
                )
            }.onSuccess { items ->
                val results = items.map { item -> item.toAgentDeviceContactResult(inputSource) }
                args.onAgentLookupDeviceContactsResolved(results, null, null)
            }.onFailure {
                args.onAgentLookupDeviceContactsResolved(
                    request.names.map { name ->
                        mapOf(
                            "name" to name,
                            "status" to "UNAVAILABLE",
                            "inputSource" to args.assistantUiState.agentContactInputSource.wireValue
                        )
                    },
                    currentAppText("通讯录查询失败", "Contacts lookup failed"),
                    null
                )
            }
        }
    }
}

internal fun DeviceContactsLookupItem.toAgentDeviceContactResult(
    inputSource: AgentContactInputSource
): Map<String, Any?> {
    return buildMap {
        put("name", name)
        put("requestedName", name)
        put("status", status)
        put("inputSource", inputSource.wireValue)
        matchType?.let { put("matchType", it) }
        if (candidates.isNotEmpty()) {
            put("candidates", candidates.map { candidate ->
                buildMap<String, Any?> {
                    put("displayName", candidate.displayName)
                    put("resolvedName", candidate.displayName)
                    put("phoneNumber", candidate.phoneNumber)
                    candidate.contactId?.let { put("contactId", it) }
                    candidate.label?.let { put("label", it) }
                }
            })
        }
        candidates.firstOrNull()?.let { candidate ->
            if (status == "RESOLVED") {
                put("displayName", candidate.displayName)
                put("resolvedName", candidate.displayName)
                put("phoneNumber", candidate.phoneNumber)
                candidate.contactId?.let { put("contactId", it) }
                candidate.label?.let { put("label", it) }
            }
        }
    }
}
