package com.vvtech.aiassistant.features.assistant

import android.content.Context
import android.content.SharedPreferences
import android.widget.Toast
import androidx.compose.runtime.Composable
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.snapshots.SnapshotStateList
import androidx.compose.runtime.setValue
import com.vvtech.aiassistant.account.AccountIdentityProvider
import com.vvtech.aiassistant.data.model.ContactDirectoryEntry
import com.vvtech.aiassistant.data.model.ContactDirectoryUpsertRequest
import com.vvtech.aiassistant.data.model.UserIdentityPayload
import com.vvtech.aiassistant.data.model.UserIdentityUpsertRequest
import com.vvtech.aiassistant.data.repository.AssistantRepository
import com.vvtech.aiassistant.features.assistant_contacts.AssistantContactDirectoryRuntimeController
import com.vvtech.aiassistant.features.assistant_contacts.normalizeAssistantContactPhoneKey
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText
import com.vvtech.aiassistant.features.assistant_initialization.AssistantInitializationLoadState
import com.vvtech.aiassistant.features.assistant_initialization.shouldShowAssistantInitialization
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

private const val IdentityInitializationSkippedKey = "identity_initialization_skipped"

internal class AssistantContactRuntimeController(
    private val state: AssistantContactRuntimeState,
    private val deps: AssistantContactRuntimeDeps,
    private val directoryController: AssistantContactDirectoryRuntimeController,
    callbacks: AssistantContactRuntimeCallbacks
) {
    private var callbacks = callbacks
    val contactRecords: SnapshotStateList<FinalContactRecord> = state.contactRecords
    val contactMethods: SnapshotStateList<PersonalInfoEntry> = state.contactMethods

    var contactDirectoryEntries by state.contactDirectoryEntries
    var contactDirectoryLoading by state.contactDirectoryLoading
    var contactDirectoryError by state.contactDirectoryError
    var directoryDetailPhone by state.directoryDetailPhone
    var directoryDetailSaving by state.directoryDetailSaving
    var directoryDetailError by state.directoryDetailError
    var userIdentityPayload by state.userIdentityPayload
    var userIdentityLoading by state.userIdentityLoading
    var userIdentityLoadState by state.userIdentityLoadState
    var userIdentitySaving by state.userIdentitySaving
    var userIdentityError by state.userIdentityError
    var identityOverlaySaving by state.identityOverlaySaving
    var identityOverlayError by state.identityOverlayError
    var identityCompletionOnly by state.identityCompletionOnly
    var identityInitSkippedThisSession by state.identityInitSkippedThisSession
    var selectedMethodId by state.selectedMethodId
    var selectedContactName by state.selectedContactName
    var selectedContactPhone by state.selectedContactPhone
    var selectedContactSystemDialPhone by state.selectedContactSystemDialPhone
    var selectedContactHint by state.selectedContactHint
    var editMode by state.editMode
    var editingMethodId by state.editingMethodId
    var contactNameDraft by state.contactNameDraft
    var contactGenderDraft by state.contactGenderDraft
    var contactPhoneDraft by state.contactPhoneDraft
    var contactEditError by state.contactEditError

    val directoryDetailInitial: ContactDirectoryEntry?
        get() = if (directoryDetailPhone.isBlank()) {
            null
        } else {
            contactDirectoryEntries.firstOrNull {
                normalizeAssistantContactPhoneKey(it.phone) == normalizeAssistantContactPhoneKey(directoryDetailPhone)
            }
        }

    val defaultMethod: PersonalInfoEntry?
        get() = contactMethods.firstOrNull { it.isDefault }

    val identityNeedsInit: Boolean
        get() = shouldShowAssistantInitialization(
            loadState = userIdentityLoadState,
            identityName = userIdentityPayload?.name
        )

    fun updateCallbacks(callbacks: AssistantContactRuntimeCallbacks) {
        this.callbacks = callbacks
        directoryController.updateCallbacks(callbacks)
    }

    fun refreshDeviceContacts(onComplete: (() -> Unit)? = null) =
        directoryController.refreshDeviceContacts(onComplete)

    fun refreshContactDirectory() =
        directoryController.refreshContactDirectory()

    fun saveContactDirectoryEntry(request: ContactDirectoryUpsertRequest) =
        directoryController.saveContactDirectoryEntry(request)

    fun deleteContactDirectoryEntry(phone: String) =
        directoryController.deleteContactDirectoryEntry(phone)

    fun refreshUserIdentity() {
        val userId = AccountIdentityProvider.accountId
        if (userId.isBlank()) {
            userIdentityPayload = null
            userIdentityLoading = false
            userIdentityLoadState = AssistantInitializationLoadState.UNKNOWN
            return
        }
        if (userIdentityLoading) return
        userIdentityLoading = true
        userIdentityLoadState = AssistantInitializationLoadState.LOADING
        userIdentityError = null
        deps.scope.launch {
            runCatching { deps.repository.getUserIdentity(userId) }
                .onSuccess { payload ->
                    userIdentityPayload = payload
                    userIdentityLoading = false
                    userIdentityLoadState = AssistantInitializationLoadState.LOADED
                }
                .onFailure { throwable ->
                    userIdentityLoading = false
                    userIdentityError = throwable.message ?: currentAppText("身份资料加载失败", "Failed to load identity details")
                    userIdentityLoadState = AssistantInitializationLoadState.FAILED
                }
        }
    }

    fun saveUserIdentityFromScreen(request: UserIdentityUpsertRequest) {
        val userId = AccountIdentityProvider.accountId
        if (userId.isBlank()) return
        val validationError = myIdentityValidationError(request)
        if (validationError != null) {
            userIdentityError = validationError
            return
        }
        userIdentitySaving = true
        val shouldReturnToSettings = shouldReturnToSettingsAfterIdentitySave(userIdentityPayload)
        userIdentityError = null
        deps.scope.launch {
            runCatching {
                saveUserIdentityForScreen(deps.repository, userIdentityPayload, request, userId)
            }.onSuccess { payload ->
                userIdentityPayload = payload
                userIdentityLoadState = AssistantInitializationLoadState.LOADED
                userIdentitySaving = false
                Toast.makeText(deps.context, currentAppText("身份资料已保存", "Identity details saved"), Toast.LENGTH_SHORT).show()
                if (shouldReturnToSettings) callbacks.onPageChange(FinalPage.Settings)
            }.onFailure { throwable ->
                userIdentitySaving = false
                userIdentityError = finalUserIdentitySaveErrorMessage(throwable)
            }
        }
    }

    fun deleteUserIdentityFromScreen() {
        val userId = AccountIdentityProvider.accountId
        if (userId.isBlank() || userIdentitySaving) return
        userIdentitySaving = true
        userIdentityError = null
        deps.scope.launch {
            runCatching {
                deps.repository.deleteUserIdentity(userId)
            }.onSuccess { payload ->
                identityInitSkippedThisSession = true
                deps.prefs.edit().putBoolean(IdentityInitializationSkippedKey, true).apply()
                userIdentityPayload = payload
                userIdentityLoadState = AssistantInitializationLoadState.LOADED
                userIdentitySaving = false
                Toast.makeText(deps.context, currentAppText("身份已删除，已切换为默认音色", "Identity deleted. Switched to the default voice"), Toast.LENGTH_SHORT).show()
            }.onFailure { throwable ->
                userIdentitySaving = false
                userIdentityError = throwable.message ?: currentAppText("删除身份失败", "Failed to delete identity")
            }
        }
    }

    fun saveUserIdentityFromOverlay(request: UserIdentityUpsertRequest, onResumeTaskEntry: () -> Unit = {}) {
        val userId = AccountIdentityProvider.accountId
        if (userId.isBlank()) return
        val validationError = finalUserIdentityValidationError(request)
        if (validationError != null) {
            identityOverlayError = validationError
            return
        }
        identityOverlaySaving = true
        identityOverlayError = null
        val resumeTaskEntry = identityCompletionOnly
        deps.scope.launch {
            runCatching {
                deps.repository.upsertUserIdentity(request.copy(userId = userId))
            }.onSuccess { payload ->
                userIdentityPayload = payload
                userIdentityLoadState = AssistantInitializationLoadState.LOADED
                identityOverlaySaving = false
                callbacks.onIdentityOverlaySaved()
                if (resumeTaskEntry) {
                    onResumeTaskEntry()
                }
                Toast.makeText(deps.context, currentAppText("身份资料已保存", "Identity details saved"), Toast.LENGTH_SHORT).show()
            }.onFailure { throwable ->
                identityOverlaySaving = false
                identityOverlayError = finalUserIdentitySaveErrorMessage(throwable)
            }
        }
    }

    fun applyContactMethods(updated: List<PersonalInfoEntry>) {
        val normalized = updated.take(FinalMaxPersonalInfoCount).ensureSingleDefault()
        contactMethods.clear()
        contactMethods.addAll(normalized)
        saveFinalContactMethods(deps.prefs, normalized)
    }

    fun persistTaskContactIfNeeded(contact: EffectiveTaskContact): EffectiveTaskContact {
        val normalizedPhone = normalizeMainlandPhone(contact.phone)
        val normalizedContact = contact.copy(
            name = contact.name.trim(),
            phone = normalizedPhone.ifBlank { contact.phone.trim() },
            idCardNumber = contact.idCardNumber.trim()
        )
        if (
            normalizedContact.name.isNotBlank() &&
            normalizedPhone.isNotBlank() &&
            contactMethods.none { normalizeMainlandPhone(it.phone) == normalizedPhone }
        ) {
            applyContactMethods(
                contactMethods.toList() + PersonalInfoEntry(
                    id = "cm_${System.currentTimeMillis()}",
                    name = normalizedContact.name,
                    gender = normalizedContact.gender,
                    phone = normalizedPhone,
                    idCardNumber = normalizedContact.idCardNumber,
                    isDefault = contactMethods.isEmpty()
                )
            )
        }
        return normalizedContact
    }

    fun beginAddContactMethod() {
        editMode = ContactEditMode.Add.name
        editingMethodId = null
        contactNameDraft = ""
        contactGenderDraft = PersonalInfoGender.Mr.name
        contactPhoneDraft = ""
        contactEditError = null
        callbacks.onOpenContactMethodEdit()
    }

    fun beginEditContactMethod(entry: PersonalInfoEntry) {
        editMode = ContactEditMode.Edit.name
        editingMethodId = entry.id
        contactNameDraft = entry.name
        contactGenderDraft = entry.gender.name
        contactPhoneDraft = entry.phone
        contactEditError = null
        callbacks.onOpenContactMethodEdit()
    }

    fun reloadContactMethodsFromPrefs() {
        contactMethods.clear()
        contactMethods.addAll(loadFinalContactMethods(deps.prefs))
    }

    fun clearContactRecords() {
        contactRecords.clear()
    }

    fun clearContactMethods() {
        contactMethods.clear()
    }

    fun resetSelection() {
        selectedMethodId = null
    }

    fun applyDeveloperDataModeContactState(
        mode: DeveloperDataMode,
        contactsPermissionGranted: Boolean,
        currentPage: FinalPage
    ) {
        when (mode) {
            DeveloperDataMode.Filled -> {
                if (contactsPermissionGranted) {
                    refreshDeviceContacts()
                } else {
                    clearContactRecords()
                }
                reloadContactMethodsFromPrefs()
            }
            DeveloperDataMode.Empty -> {
                clearContactRecords()
                clearContactMethods()
            }
        }
        resetSelection()
        if (currentPage == FinalPage.ContactDetail && contactRecords.isEmpty()) {
            callbacks.onPageChange(FinalPage.Contacts)
        }
        if (currentPage == FinalPage.ContactMethodEdit && contactMethods.isEmpty()) {
            callbacks.onPageChange(FinalPage.ContactMethods)
        }
    }

    fun showIdentityInitOverlay(completionOnly: Boolean = false) {
        identityCompletionOnly = completionOnly
        callbacks.onIdentityInitOverlayVisibleChange(true)
    }

    fun dismissIdentityInitOverlay() {
        identityOverlayError = null
        identityCompletionOnly = false
        callbacks.onIdentityInitOverlayVisibleChange(false)
    }

    fun skipInitialIdentityForSession() {
        identityInitSkippedThisSession = true
        deps.prefs.edit().putBoolean(IdentityInitializationSkippedKey, true).apply()
        dismissIdentityInitOverlay()
    }

    fun buildArgsInput(
        voiceLanguage: VoiceLanguage,
        externalCallbacks: AssistantContactRuntimeExternalCallbacks
    ): AssistantContactArgsBuilderInput {
        return AssistantContactArgsBuilderInput(
            ContactArgsBaseInput(voiceLanguage, contactRecords),
            ContactArgsSelectionInput(
                selectedContactName,
                selectedContactPhone,
                selectedContactSystemDialPhone,
                selectedContactHint
            ),
            ContactArgsDirectoryInput(
                directoryDetailPhone, directoryDetailInitial, directoryDetailSaving, contactDirectoryLoading,
                directoryDetailError
            ),
            ContactArgsIdentityInput(userIdentityPayload, userIdentitySaving, userIdentityLoading, userIdentityError),
            ContactArgsMethodsInput(contactMethods, selectedMethodId),
            ContactArgsEditInput(
                editMode, editingMethodId, contactNameDraft, contactGenderDraft,
                contactPhoneDraft, contactEditError
            ),
            ContactArgsCallbacksInput(
                ContactSelectionCallbacksInput(
                    { selectedContactName = it },
                    { selectedContactPhone = it },
                    { selectedContactSystemDialPhone = it },
                    { selectedContactHint = it }
                ),
                ContactDirectoryCallbacksInput(
                    { directoryDetailPhone = it },
                    { directoryDetailError = it },
                    ::saveContactDirectoryEntry,
                    ::deleteContactDirectoryEntry
                ),
                ContactActionCallbacksInput(
                    externalCallbacks.onCallContact
                ),
                ContactIdentityCallbacksInput(
                    { userIdentityError = it },
                    ::refreshUserIdentity,
                    ::saveUserIdentityFromScreen,
                    ::deleteUserIdentityFromScreen
                ),
                ContactMethodCallbacksInput(
                    { selectedMethodId = it },
                    ::beginEditContactMethod,
                    ::applyContactMethods,
                    ::beginAddContactMethod
                ),
                ContactEditCallbacksInput(
                    { contactNameDraft = it },
                    { contactGenderDraft = it },
                    { contactPhoneDraft = it },
                    { contactEditError = it }
                )
            )
        )
    }
}

internal class AssistantContactRuntimeState(
    val contactRecords: SnapshotStateList<FinalContactRecord>,
    val contactDirectoryEntries: MutableState<List<ContactDirectoryEntry>>,
    val contactDirectoryLoading: MutableState<Boolean>,
    val contactDirectoryError: MutableState<String?>,
    val directoryDetailPhone: MutableState<String>,
    val directoryDetailSaving: MutableState<Boolean>,
    val directoryDetailError: MutableState<String?>,
    val userIdentityPayload: MutableState<UserIdentityPayload?>,
    val userIdentityLoading: MutableState<Boolean>,
    val userIdentityLoadState: MutableState<AssistantInitializationLoadState>,
    val userIdentitySaving: MutableState<Boolean>,
    val userIdentityError: MutableState<String?>,
    val identityOverlaySaving: MutableState<Boolean>,
    val identityOverlayError: MutableState<String?>,
    val identityCompletionOnly: MutableState<Boolean>,
    val identityInitSkippedThisSession: MutableState<Boolean>,
    val contactMethods: SnapshotStateList<PersonalInfoEntry>,
    val selectedMethodId: MutableState<String?>,
    val selectedContactName: MutableState<String>,
    val selectedContactPhone: MutableState<String>,
    val selectedContactSystemDialPhone: MutableState<String>,
    val selectedContactHint: MutableState<String>,
    val editMode: MutableState<String>,
    val editingMethodId: MutableState<String?>,
    val contactNameDraft: MutableState<String>,
    val contactGenderDraft: MutableState<String>,
    val contactPhoneDraft: MutableState<String>,
    val contactEditError: MutableState<String?>
)

internal data class AssistantContactRuntimeDeps(
    val context: Context,
    val prefs: SharedPreferences,
    val repository: AssistantRepository,
    val scope: CoroutineScope
)

internal data class AssistantContactRuntimeCallbacks(
    val onContactsPermissionGrantedChange: (Boolean) -> Unit,
    val onPageChange: (FinalPage) -> Unit,
    val onOpenContactMethodEdit: () -> Unit,
    val onIdentityOverlaySaved: () -> Unit,
    val onIdentityInitOverlayVisibleChange: (Boolean) -> Unit
)

internal data class AssistantContactRuntimeExternalCallbacks(
    val onCallContact: () -> Unit
)

@Composable
internal fun rememberAssistantContactRuntimeController(
    deps: AssistantContactRuntimeDeps,
    callbacks: AssistantContactRuntimeCallbacks
): AssistantContactRuntimeController {
    val state = AssistantContactRuntimeState(
        contactRecords = remember { mutableStateListOf() },
        contactDirectoryEntries = remember { mutableStateOf<List<ContactDirectoryEntry>>(emptyList()) },
        contactDirectoryLoading = rememberSaveable { mutableStateOf(false) },
        contactDirectoryError = rememberSaveable { mutableStateOf<String?>(null) },
        directoryDetailPhone = rememberSaveable { mutableStateOf("") },
        directoryDetailSaving = rememberSaveable { mutableStateOf(false) },
        directoryDetailError = rememberSaveable { mutableStateOf<String?>(null) },
        userIdentityPayload = remember { mutableStateOf<UserIdentityPayload?>(null) },
        userIdentityLoading = remember { mutableStateOf(false) },
        userIdentityLoadState = remember {
            mutableStateOf(AssistantInitializationLoadState.UNKNOWN)
        },
        userIdentitySaving = rememberSaveable { mutableStateOf(false) },
        userIdentityError = rememberSaveable { mutableStateOf<String?>(null) },
        identityOverlaySaving = rememberSaveable { mutableStateOf(false) },
        identityOverlayError = rememberSaveable { mutableStateOf<String?>(null) },
        identityCompletionOnly = rememberSaveable { mutableStateOf(false) },
        identityInitSkippedThisSession = remember(deps.prefs) {
            mutableStateOf(deps.prefs.getBoolean(IdentityInitializationSkippedKey, false))
        },
        contactMethods = remember(deps.prefs) {
            mutableStateListOf<PersonalInfoEntry>().apply {
                addAll(loadFinalContactMethods(deps.prefs))
            }
        },
        selectedMethodId = rememberSaveable { mutableStateOf<String?>(null) },
        selectedContactName = rememberSaveable { mutableStateOf("") },
        selectedContactPhone = rememberSaveable { mutableStateOf("") },
        selectedContactSystemDialPhone = rememberSaveable { mutableStateOf("") },
        selectedContactHint = rememberSaveable { mutableStateOf("") },
        editMode = rememberSaveable { mutableStateOf(ContactEditMode.Add.name) },
        editingMethodId = rememberSaveable { mutableStateOf<String?>(null) },
        contactNameDraft = rememberSaveable { mutableStateOf("") },
        contactGenderDraft = rememberSaveable { mutableStateOf(PersonalInfoGender.Mr.name) },
        contactPhoneDraft = rememberSaveable { mutableStateOf("") },
        contactEditError = rememberSaveable { mutableStateOf<String?>(null) }
    )
    val directoryController = remember(state, deps) {
        AssistantContactDirectoryRuntimeController(state, deps, callbacks)
    }
    val controller = remember(deps.context, deps.prefs, deps.repository, deps.scope, directoryController) {
        AssistantContactRuntimeController(state, deps, directoryController, callbacks)
    }
    controller.updateCallbacks(callbacks)
    return controller
}
