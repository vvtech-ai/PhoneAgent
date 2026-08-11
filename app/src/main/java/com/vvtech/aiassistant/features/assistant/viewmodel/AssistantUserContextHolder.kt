package com.vvtech.aiassistant.features.assistant.viewmodel

import android.content.Context
import android.content.pm.PackageManager
import android.location.Geocoder
import android.os.SystemClock
import androidx.core.content.ContextCompat
import com.vvtech.aiassistant.contacts.DeviceContactResolver
import com.vvtech.aiassistant.location.FusedLocationProvider
import com.vvtech.aiassistant.logging.AppFileLogger
import com.vvtech.aiassistant.model.DefaultReservationContactPayload
import com.vvtech.aiassistant.model.DeviceContactPayload
import com.vvtech.aiassistant.model.OcrAttachmentContextPayload
import com.vvtech.aiassistant.model.UserContextPayload
import com.vvtech.aiassistant.model.UserCurrentTimePayload
import com.vvtech.aiassistant.features.assistant.DevicePhoneContact
import com.vvtech.aiassistant.features.assistant.FinalPrefsName
import com.vvtech.aiassistant.features.assistant.Index9AssistantUiState
import com.vvtech.aiassistant.features.assistant.PersonalInfoEntry
import com.vvtech.aiassistant.features.assistant.loadFinalContactMethods
import com.vvtech.aiassistant.features.assistant.normalizeMainlandPhone
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.util.Locale
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull

internal class AssistantUserContextHolder(
    private val appContext: Context,
    private val uiState: MutableStateFlow<Index9AssistantUiState>,
    private val scope: CoroutineScope,
    private val log: (String) -> Unit
) {
    private var lastLocationRefreshAtElapsed: Long = 0L
    private var locationRefreshJob: Job? = null

    internal var latestUserContext: UserContextPayload? = null
        private set

    @Volatile
    private var pureVoiceOcrAttachments: List<OcrAttachmentContextPayload> = emptyList()

    @Volatile
    private var cachedSystemDeviceContacts: List<DevicePhoneContact>? = null

    @Volatile
    private var systemDeviceContactsLoading: Boolean = false

    internal fun markSystemDeviceContactsLoading() {
        systemDeviceContactsLoading = true
    }

    internal fun updateSystemDeviceContactsCache(contacts: List<DevicePhoneContact>) {
        cachedSystemDeviceContacts = contacts
        systemDeviceContactsLoading = false
    }

    internal fun clearSystemDeviceContactsCache() {
        cachedSystemDeviceContacts = null
        systemDeviceContactsLoading = false
    }

    internal fun updatePureVoiceOcrContext(
        attachments: List<OcrAttachmentContextPayload>
    ) {
        pureVoiceOcrAttachments = attachments.toList()
    }

    internal fun latestTransportUserContext(): UserContextPayload? {
        val base = latestUserContext
        if (base == null && pureVoiceOcrAttachments.isEmpty()) return null
        return (base ?: UserContextPayload()).copy(
            ocrAttachments = pureVoiceOcrAttachments.takeIf { it.isNotEmpty() }
        )
    }

    internal suspend fun loadSystemDeviceContactsForUi(): List<DevicePhoneContact> {
        markSystemDeviceContactsLoading()
        return runCatching {
            DeviceContactResolver(appContext).loadPhoneContacts()
        }.onSuccess { contacts ->
            updateSystemDeviceContactsCache(contacts)
        }.onFailure {
            clearSystemDeviceContactsCache()
        }.getOrThrow()
    }

    internal fun currentAgentUserContext(
        deviceContacts: List<DeviceContactPayload> = emptyList()
    ): UserContextPayload {
        val base = latestTransportUserContext() ?: UserContextPayload()
        return base.copy(
            defaultReservationContact = defaultReservationContactPayload(),
            reservationContacts = reservationContactPayloads(),
            currentTime = currentTimePayload(),
            permissionStatus = currentPermissionStatusSnapshot(),
            deviceContacts = deviceContacts.takeIf { it.isNotEmpty() },
            ocrAttachments = pureVoiceOcrAttachments.takeIf { it.isNotEmpty() }
        )
    }

    internal suspend fun currentFreshAgentUserContext(
        reason: String,
        message: String? = null
    ): UserContextPayload {
        val refreshed = withTimeoutOrNull(AgentTurnLocationAwaitMillis) {
            refreshLocationIfPermitted(force = false, reason = reason)
        }
        if (refreshed == null && latestUserContext == null) {
            log("currentFreshAgentUserContext location unavailable reason=$reason")
            AppFileLogger.i(
                "LOCATION_DIAG",
                "agent_context_location_unavailable reason=$reason awaitMs=$AgentTurnLocationAwaitMillis"
            )
        }
        return currentAgentUserContext()
    }

    internal fun currentPermissionStatusSnapshot(): Map<String, String> {
        val fineLocationGranted = hasPermission(android.Manifest.permission.ACCESS_FINE_LOCATION)
        val coarseLocationGranted =
            hasPermission(android.Manifest.permission.ACCESS_COARSE_LOCATION)
        return linkedMapOf(
            "microphone" to runtimePermissionStatus(android.Manifest.permission.RECORD_AUDIO),
            "contacts" to runtimePermissionStatus(android.Manifest.permission.READ_CONTACTS),
            "location" to if (fineLocationGranted || coarseLocationGranted) "OK" else "NOT_GRANTED",
            "document_picker" to if (hasDocumentPicker()) "OK" else "UNAVAILABLE"
        )
    }

    private fun runtimePermissionStatus(permission: String): String {
        return if (hasPermission(permission)) "OK" else "NOT_GRANTED"
    }

    private fun hasPermission(permission: String): Boolean {
        return ContextCompat.checkSelfPermission(
            appContext,
            permission
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun hasDocumentPicker(): Boolean {
        return true
    }

    private fun defaultReservationContactPayload(): DefaultReservationContactPayload? {
        val prefs = appContext.getSharedPreferences(FinalPrefsName, Context.MODE_PRIVATE)
        val entries = loadFinalContactMethods(prefs)
        val entry = entries.firstOrNull { it.isDefault } ?: entries.firstOrNull()
        ?: return null
        return entry.toReservationContactPayload()
    }

    private fun reservationContactPayloads(): List<DefaultReservationContactPayload>? {
        val prefs = appContext.getSharedPreferences(FinalPrefsName, Context.MODE_PRIVATE)
        val contacts = loadFinalContactMethods(prefs)
            .mapNotNull { it.toReservationContactPayload() }
        return contacts.takeIf { it.isNotEmpty() }
    }

    private fun PersonalInfoEntry.toReservationContactPayload(): DefaultReservationContactPayload? {
        val normalizedPhone = normalizeMainlandPhone(phone).ifBlank { phone.trim() }
        val name = name.trim()
        val idCardNumber = idCardNumber.trim()
        if (name.isBlank() && normalizedPhone.isBlank() && idCardNumber.isBlank()) {
            return null
        }
        return DefaultReservationContactPayload(
            name = name.ifBlank { null },
            gender = gender.name,
            phone = normalizedPhone.ifBlank { null },
            idCardNumber = idCardNumber.ifBlank { null },
            isDefault = isDefault
        )
    }

    private fun currentTimePayload(): UserCurrentTimePayload {
        val now = ZonedDateTime.now()
        return UserCurrentTimePayload(
            isoDateTime = now.format(DateTimeFormatter.ISO_OFFSET_DATE_TIME),
            timezone = now.zone.id
        )
    }

    internal fun loadLocationIfPermitted() {
        scope.launch {
            refreshLocationIfPermitted(force = false, reason = "screen_enter")
        }
    }

    private fun updateLocationUiState() {
        val ctx = latestUserContext
        val available = ctx?.lat != null && ctx.lng != null
        val text = if (available) {
            "${"%.4f".format(ctx!!.lat!!)}, ${"%.4f".format(ctx.lng!!)}"
        } else ""
        uiState.update { state ->
            AssistantUiStateReducer.updateLocationAvailability(state, available, text)
        }
    }

    private suspend fun reverseGeocodeAndUpdateDisplay(lat: Double, lng: Double) {
        try {
            val geocoder = Geocoder(appContext, Locale.CHINA)
            val addresses = withContext(Dispatchers.IO) {
                geocoder.getFromLocation(lat, lng, 1)
            }
            if (!addresses.isNullOrEmpty()) {
                val addr = addresses[0]
                val fullAddr = if (!addr.getAddressLine(0).isNullOrBlank()) {
                    addr.getAddressLine(0)
                } else {
                    listOfNotNull(
                        addr.locality,
                        addr.subLocality,
                        addr.thoroughfare,
                        addr.subThoroughfare
                    )
                        .filter { it.isNotBlank() }
                        .joinToString("")
                }
                uiState.update { state ->
                    AssistantUiStateReducer.updateLocationDisplayText(state, fullAddr)
                }
            }
        } catch (e: Exception) {
            AppFileLogger.w("LOCATION_DIAG", "reverseGeocode failed lat=$lat lng=$lng", e)
        }
    }

    internal suspend fun refreshLocationIfPermitted(
        force: Boolean,
        reason: String
    ): UserContextPayload? {
        val fineGranted = ContextCompat.checkSelfPermission(
            appContext,
            android.Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        val coarseGranted = ContextCompat.checkSelfPermission(
            appContext,
            android.Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        if (!fineGranted && !coarseGranted) {
            log("refreshLocation skipped reason=$reason no_permission")
            return latestUserContext
        }

        val now = SystemClock.elapsedRealtime()
        if (!force && latestUserContext != null && now - lastLocationRefreshAtElapsed < LocationRefreshTtlMillis) {
            log(
                "refreshLocation reused reason=$reason ageMs=${now - lastLocationRefreshAtElapsed} " +
                    "lat=${latestUserContext?.lat} lng=${latestUserContext?.lng}"
            )
            return latestUserContext
        }

        locationRefreshJob?.takeIf { it.isActive }?.let { activeJob ->
            log("refreshLocation join active reason=$reason")
            activeJob.join()
            return latestUserContext
        }

        val refreshJob = scope.launch {
            log(
                "refreshLocation start reason=$reason force=$force " +
                    "currentLat=${latestUserContext?.lat} currentLng=${latestUserContext?.lng}"
            )
            runCatching { FusedLocationProvider(appContext).locateOnce() }
                .onSuccess { result ->
                    if (result.success && result.userContext != null) {
                        latestUserContext = result.userContext
                        lastLocationRefreshAtElapsed = SystemClock.elapsedRealtime()
                        updateLocationUiState()
                        result.userContext.lat?.let { lat ->
                            result.userContext.lng?.let { lng ->
                                launch { reverseGeocodeAndUpdateDisplay(lat, lng) }
                            }
                        }
                        log(
                            "refreshLocation success reason=$reason summary=${result.summary} " +
                                "lat=${result.userContext.lat} lng=${result.userContext.lng}"
                        )
                    } else {
                        log("refreshLocation no_update reason=$reason summary=${result.summary}")
                    }
                }
                .onFailure { throwable ->
                    log("refreshLocation failed reason=$reason error=${throwable.message}")
                }
        }
        locationRefreshJob = refreshJob
        refreshJob.invokeOnCompletion {
            if (locationRefreshJob === refreshJob) {
                locationRefreshJob = null
            }
        }
        refreshJob.join()
        return latestUserContext
    }
}
