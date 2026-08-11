package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.data.model.ContactDirectoryEntry
import com.vvtech.aiassistant.data.model.ContactDirectoryUpsertRequest
import com.vvtech.aiassistant.data.model.UserIdentityPayload
import com.vvtech.aiassistant.data.model.UserIdentityUpsertRequest

internal class AssistantContactArgsBuilderInput(
    val base: ContactArgsBaseInput,
    val selection: ContactArgsSelectionInput,
    val directory: ContactArgsDirectoryInput,
    val identity: ContactArgsIdentityInput,
    val methods: ContactArgsMethodsInput,
    val edit: ContactArgsEditInput,
    val callbacks: ContactArgsCallbacksInput
)

internal class ContactArgsBaseInput(
    val voiceLanguage: VoiceLanguage,
    val contactRecords: List<FinalContactRecord>
)

internal class ContactArgsSelectionInput(
    val selectedContactName: String,
    val selectedContactPhone: String,
    val selectedContactSystemDialPhone: String,
    val selectedContactHint: String
)

internal class ContactArgsDirectoryInput(
    val directoryDetailPhone: String,
    val directoryDetailInitial: ContactDirectoryEntry?,
    val directoryDetailSaving: Boolean,
    val contactDirectoryLoading: Boolean,
    val directoryDetailError: String?
)

internal class ContactArgsIdentityInput(
    val userIdentityPayload: UserIdentityPayload?,
    val userIdentitySaving: Boolean,
    val userIdentityLoading: Boolean,
    val userIdentityError: String?
)

internal class ContactArgsMethodsInput(
    val contactMethods: List<PersonalInfoEntry>,
    val selectedMethodId: String?
)

internal class ContactArgsEditInput(
    val editMode: String,
    val editingMethodId: String?,
    val contactNameDraft: String,
    val contactGenderDraft: String,
    val contactPhoneDraft: String,
    val contactEditError: String?
)

internal class ContactArgsCallbacksInput(
    val selection: ContactSelectionCallbacksInput,
    val directory: ContactDirectoryCallbacksInput,
    val actions: ContactActionCallbacksInput,
    val identity: ContactIdentityCallbacksInput,
    val methods: ContactMethodCallbacksInput,
    val edit: ContactEditCallbacksInput
)

internal class ContactSelectionCallbacksInput(
    val onSelectedContactNameChange: (String) -> Unit,
    val onSelectedContactPhoneChange: (String) -> Unit,
    val onSelectedContactSystemDialPhoneChange: (String) -> Unit,
    val onSelectedContactHintChange: (String) -> Unit
)

internal class ContactDirectoryCallbacksInput(
    val onDirectoryDetailPhoneChange: (String) -> Unit,
    val onDirectoryDetailErrorChange: (String?) -> Unit,
    val onSaveDirectoryEntry: (ContactDirectoryUpsertRequest) -> Unit,
    val onDeleteDirectoryEntry: (String) -> Unit
)

internal class ContactActionCallbacksInput(
    val onCallContact: () -> Unit
)

internal class ContactIdentityCallbacksInput(
    val onUserIdentityErrorChange: (String?) -> Unit,
    val onRefreshUserIdentity: () -> Unit,
    val onSaveUserIdentity: (UserIdentityUpsertRequest) -> Unit,
    val onDeleteUserIdentity: () -> Unit
)

internal class ContactMethodCallbacksInput(
    val onSelectedMethodIdChange: (String?) -> Unit,
    val onEditContactMethod: (PersonalInfoEntry) -> Unit,
    val onApplyContactMethods: (List<PersonalInfoEntry>) -> Unit,
    val onBeginAddContactMethod: () -> Unit
)

internal class ContactEditCallbacksInput(
    val onContactNameDraftChange: (String) -> Unit,
    val onContactGenderDraftChange: (String) -> Unit,
    val onContactPhoneDraftChange: (String) -> Unit,
    val onContactEditErrorChange: (String?) -> Unit
)

internal fun buildAssistantContactArgs(
    input: AssistantContactArgsBuilderInput
): ContactPageArgs = ContactPageArgs().also { args ->
    val callbacks = input.callbacks
    with(input.base) {
        args.voiceLanguage = voiceLanguage
        args.contactRecords = contactRecords.toList()
    }
    with(input.selection) {
        args.selectedContactName = selectedContactName
        args.selectedContactPhone = selectedContactPhone
        args.selectedContactSystemDialPhone = selectedContactSystemDialPhone
        args.selectedContactHint = selectedContactHint
    }
    with(callbacks.selection) {
        args.onSelectedContactNameChange = onSelectedContactNameChange
        args.onSelectedContactPhoneChange = onSelectedContactPhoneChange
        args.onSelectedContactSystemDialPhoneChange = onSelectedContactSystemDialPhoneChange
        args.onSelectedContactHintChange = onSelectedContactHintChange
    }
    with(input.directory) {
        args.directoryDetailPhone = directoryDetailPhone
        args.directoryDetailInitial = directoryDetailInitial
        args.directoryDetailSaving = directoryDetailSaving
        args.contactDirectoryLoading = contactDirectoryLoading
        args.directoryDetailError = directoryDetailError
    }
    with(callbacks.directory) {
        args.onDirectoryDetailPhoneChange = onDirectoryDetailPhoneChange
        args.onDirectoryDetailErrorChange = onDirectoryDetailErrorChange
        args.onSaveDirectoryEntry = onSaveDirectoryEntry
        args.onDeleteDirectoryEntry = onDeleteDirectoryEntry
    }
    with(callbacks.actions) {
        args.onCallContact = onCallContact
    }
    with(input.identity) {
        args.userIdentityPayload = userIdentityPayload
        args.userIdentitySaving = userIdentitySaving
        args.userIdentityLoading = userIdentityLoading
        args.userIdentityError = userIdentityError
    }
    with(callbacks.identity) {
        args.onUserIdentityErrorChange = onUserIdentityErrorChange
        args.onRefreshUserIdentity = onRefreshUserIdentity
        args.onSaveUserIdentity = onSaveUserIdentity
        args.onDeleteUserIdentity = onDeleteUserIdentity
    }
    with(input.methods) {
        args.contactMethods = contactMethods.toList()
        args.selectedMethodId = selectedMethodId
    }
    with(callbacks.methods) {
        args.onSelectedMethodIdChange = onSelectedMethodIdChange
        args.onEditContactMethod = onEditContactMethod
        args.onApplyContactMethods = onApplyContactMethods
        args.onBeginAddContactMethod = onBeginAddContactMethod
    }
    with(input.edit) {
        args.editMode = editMode
        args.editingMethodId = editingMethodId
        args.contactNameDraft = contactNameDraft
        args.contactGenderDraft = contactGenderDraft
        args.contactPhoneDraft = contactPhoneDraft
        args.contactEditError = contactEditError
    }
    with(callbacks.edit) {
        args.onContactNameDraftChange = onContactNameDraftChange
        args.onContactGenderDraftChange = onContactGenderDraftChange
        args.onContactPhoneDraftChange = onContactPhoneDraftChange
        args.onContactEditErrorChange = onContactEditErrorChange
    }
}
