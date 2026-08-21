package com.vvtech.aiassistant.features.assistant

import com.vvtech.aiassistant.data.model.ContactDirectoryEntry
import com.vvtech.aiassistant.data.model.ContactDirectoryUpsertRequest
import com.vvtech.aiassistant.data.model.UserIdentityPayload
import com.vvtech.aiassistant.data.model.UserIdentityUpsertRequest
import com.vvtech.aiassistant.features.assistant_contacts.buildContactRemarkUpsertRequest
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText

internal class AssistantContactPageHostArgs(
    val currentPage: FinalPage,
    val contactList: ContactListPageHostArgs,
    val contactDetail: ContactDetailPageHostArgs,
    val directoryDetail: ContactDirectoryDetailPageHostArgs,
    val identity: IdentityPageHostArgs,
    val contactMethods: ContactMethodsPageHostArgs,
    val contactEdit: ContactMethodEditPageHostArgs
)

internal fun buildAssistantContactPageHostArgs(
    targetPage: FinalPage,
    navigation: PageHostNavigationArgs,
    contact: ContactPageArgs
): AssistantContactPageHostArgs = with(contact) {
    val contactEditMode = runCatching { ContactEditMode.valueOf(editMode) }.getOrDefault(ContactEditMode.Add)
    val contactMethodEditingEntry = editingMethodId?.let { editId ->
        contactMethods.firstOrNull { it.id == editId }
    }
    AssistantContactPageHostArgs(
        currentPage = targetPage,
        contactList = ContactListPageHostArgs(
            records = contactRecords.toList(),
            onOpenDetail = { selected ->
                onSelectedContactNameChange(selected.name)
                onSelectedContactPhoneChange(selected.phone)
                onSelectedContactSystemDialPhoneChange(selected.systemDialPhone)
                onSelectedContactHintChange(selected.hint)
                onDirectoryDetailPhoneChange(selected.phone)
                onDirectoryDetailErrorChange(null)
                navigation.onPageChange(FinalPage.ContactDetail)
            }
        ),
        contactDetail = ContactDetailPageHostArgs(
            name = selectedContactName,
            phone = selectedContactPhone,
            hint = selectedContactHint,
            remark = directoryDetailInitial?.description.orEmpty(),
            saving = directoryDetailSaving,
            loading = contactDirectoryLoading,
            error = directoryDetailError,
            onBack = { navigation.onPageChange(FinalPage.Contacts) },
            onCall = onCallContact,
            onSkillSelected = { skillId ->
                navigation.onStartContactSkill(
                    skillId,
                    selectedContactName,
                    selectedContactPhone
                )
            },
            onSaveRemark = { remark ->
                onSaveDirectoryEntry(
                    buildContactRemarkUpsertRequest(
                        phone = selectedContactPhone,
                        fallbackDisplayName = selectedContactName,
                        existing = directoryDetailInitial,
                        remark = remark
                    )
                )
            }
        ),
        directoryDetail = ContactDirectoryDetailPageHostArgs(
            phone = directoryDetailPhone,
            initial = directoryDetailInitial,
            saving = directoryDetailSaving,
            loading = contactDirectoryLoading,
            error = directoryDetailError,
            onBack = { navigation.onPageChange(FinalPage.Contacts) },
            onSave = onSaveDirectoryEntry,
            onDelete = if (directoryDetailInitial != null) {
                { onDeleteDirectoryEntry(directoryDetailPhone) }
            } else null
        ),
        identity = IdentityPageHostArgs(
            initial = userIdentityPayload,
            saving = userIdentitySaving,
            loading = userIdentityLoading,
            error = userIdentityError,
            onBack = { navigation.onPageChange(FinalPage.Settings) },
            onSave = onSaveUserIdentity,
            onDelete = onDeleteUserIdentity,
            onOpenVoiceModelSettings = navigation.onOpenMyIdentityVoiceModelSettings
        ),
        contactMethods = ContactMethodsPageHostArgs(
            entries = contactMethods.toList(),
            selectedId = selectedMethodId,
            onBack = { navigation.onPageChange(FinalPage.Settings) },
            onSelect = onSelectedMethodIdChange,
            onEdit = onEditContactMethod,
            onSetDefault = onSetDefaultContactMethod@{
                val selected = selectedMethodId ?: return@onSetDefaultContactMethod
                val target = contactMethods.firstOrNull { it.id == selected && !it.isDefault }
                    ?: return@onSetDefaultContactMethod
                val updated = listOf(target.copy(isDefault = true)) +
                    contactMethods.filterNot { it.id == target.id }.map { it.copy(isDefault = false) }
                onApplyContactMethods(updated)
                onSelectedMethodIdChange(null)
            },
            onDeleteSelected = onDeleteSelectedContactMethod@{
                val selected = selectedMethodId ?: return@onDeleteSelectedContactMethod
                val target = contactMethods.firstOrNull { it.id == selected }
                    ?: return@onDeleteSelectedContactMethod
                if (target.isDefault) return@onDeleteSelectedContactMethod
                val remaining = contactMethods.filterNot { it.id == selected }
                onApplyContactMethods(remaining)
                onSelectedMethodIdChange(null)
            },
            onAdd = {
                if (contactMethods.size < FinalMaxPersonalInfoCount) {
                    onBeginAddContactMethod()
                }
            }
        ),
        contactEdit = ContactMethodEditPageHostArgs(
            mode = contactEditMode,
            name = contactNameDraft,
            gender = runCatching { PersonalInfoGender.valueOf(contactGenderDraft) }.getOrDefault(PersonalInfoGender.Mr),
            phone = contactPhoneDraft,
            error = contactEditError,
            editingEntry = contactMethodEditingEntry,
            onBack = { navigation.onPageChange(FinalPage.ContactMethods) },
            onNameChange = {
                onContactNameDraftChange(sanitizeContactMethodNameInput(it))
                onContactEditErrorChange(null)
            },
            onGenderChange = {
                onContactGenderDraftChange(it.name)
                onContactEditErrorChange(null)
            },
            onPhoneChange = {
                onContactPhoneDraftChange(it)
                onContactEditErrorChange(null)
            },
            onDelete = onDeleteContactMethod@{
                val editId = editingMethodId ?: return@onDeleteContactMethod
                val target = contactMethods.firstOrNull { it.id == editId }
                    ?: return@onDeleteContactMethod
                if (target.isDefault) {
                    onContactEditErrorChange(
                        currentAppText(
                            "默认联系方式不可直接删除，请先设置其他默认项。",
                            "The default contact method cannot be deleted directly. Set another default first."
                        )
                    )
                } else {
                    onApplyContactMethods(contactMethods.filterNot { it.id == editId })
                    onSelectedMethodIdChange(null)
                    navigation.onPageChange(FinalPage.ContactMethods)
                }
            },
            onSave = {
                val validationError = validatePersonalInfoInput(contactNameDraft, contactPhoneDraft)
                if (validationError != null) {
                    onContactEditErrorChange(validationError)
                } else {
                    val normalizedPhone = normalizeMainlandPhone(contactPhoneDraft)
                    val targetGender = runCatching { PersonalInfoGender.valueOf(contactGenderDraft) }.getOrDefault(PersonalInfoGender.Mr)
                    val updatedEntry = PersonalInfoEntry(
                        id = editingMethodId ?: "cm_${System.currentTimeMillis()}",
                        name = contactNameDraft.trim(),
                        gender = targetGender,
                        phone = normalizedPhone,
                        isDefault = editingMethodId == null && contactMethods.isEmpty()
                    )
                    val merged = if (editingMethodId == null) {
                        contactMethods.toList() + updatedEntry
                    } else {
                        contactMethods.map { entry ->
                            if (entry.id == updatedEntry.id) {
                                updatedEntry.copy(isDefault = entry.isDefault)
                            } else {
                                entry
                            }
                        }
                    }
                    onApplyContactMethods(merged)
                    onSelectedMethodIdChange(null)
                    navigation.onPageChange(FinalPage.ContactMethods)
                }
            }
        )
    )
}

internal class ContactListPageHostArgs(
    val records: List<FinalContactRecord>,
    val onOpenDetail: (FinalContactRecord) -> Unit
)

internal class ContactDetailPageHostArgs(
    val name: String,
    val phone: String,
    val hint: String,
    val remark: String,
    val saving: Boolean,
    val loading: Boolean,
    val error: String?,
    val onBack: () -> Unit,
    val onCall: () -> Unit,
    val onSkillSelected: (String) -> Boolean,
    val onSaveRemark: (String) -> Unit
)

internal class ContactDirectoryDetailPageHostArgs(
    val phone: String,
    val initial: ContactDirectoryEntry?,
    val saving: Boolean,
    val loading: Boolean,
    val error: String?,
    val onBack: () -> Unit,
    val onSave: (ContactDirectoryUpsertRequest) -> Unit,
    val onDelete: (() -> Unit)?
)

internal class IdentityPageHostArgs(
    val initial: UserIdentityPayload?,
    val saving: Boolean,
    val loading: Boolean,
    val error: String?,
    val onBack: () -> Unit,
    val onSave: (UserIdentityUpsertRequest) -> Unit,
    val onDelete: () -> Unit,
    val onOpenVoiceModelSettings: () -> Unit
)

internal class ContactMethodsPageHostArgs(
    val entries: List<PersonalInfoEntry>,
    val selectedId: String?,
    val onBack: () -> Unit,
    val onSelect: (String?) -> Unit,
    val onEdit: (PersonalInfoEntry) -> Unit,
    val onSetDefault: () -> Unit,
    val onDeleteSelected: () -> Unit,
    val onAdd: () -> Unit
)

internal class ContactMethodEditPageHostArgs(
    val mode: ContactEditMode,
    val name: String,
    val gender: PersonalInfoGender,
    val phone: String,
    val error: String?,
    val editingEntry: PersonalInfoEntry?,
    val onBack: () -> Unit,
    val onNameChange: (String) -> Unit,
    val onGenderChange: (PersonalInfoGender) -> Unit,
    val onPhoneChange: (String) -> Unit,
    val onDelete: () -> Unit,
    val onSave: () -> Unit
)
