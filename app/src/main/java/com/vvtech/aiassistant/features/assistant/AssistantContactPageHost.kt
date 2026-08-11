package com.vvtech.aiassistant.features.assistant

import androidx.compose.runtime.Composable
import com.vvtech.aiassistant.features.assistant_contacts.AssistantContactDetailPageCallbacks
import com.vvtech.aiassistant.features.assistant_contacts.AssistantContactDetailPageState
import com.vvtech.aiassistant.features.assistant_contacts.AssistantContactMethodEditPageArgs
import com.vvtech.aiassistant.features.assistant_contacts.AssistantContactMethodEditPageCallbacks
import com.vvtech.aiassistant.features.assistant_contacts.AssistantContactMethodEditPageState

@Composable
internal fun AssistantContactPageHost(args: AssistantContactPageHostArgs) {
    when (args.currentPage) {
        FinalPage.Contacts -> with(args.contactList) {
            FinalContactsPageV3(
                records = records,
                onOpenDetail = onOpenDetail
            )
        }

        FinalPage.ContactDetail -> with(args.contactDetail) {
            FinalContactDetailPageV3(
                state = AssistantContactDetailPageState(
                    name = name,
                    phone = phone,
                    hint = hint,
                    remark = remark,
                    loading = loading,
                    saving = saving,
                    error = error
                ),
                callbacks = AssistantContactDetailPageCallbacks(
                    onBack = onBack,
                    onCall = onCall,
                    onSkillSelected = onSkillSelected,
                    onSaveRemark = onSaveRemark
                )
            )
        }

        FinalPage.ContactDirectoryDetail -> with(args.directoryDetail) {
            ContactDetailScreen(
                phone = phone,
                initial = initial,
                saving = saving,
                loading = loading,
                error = error,
                onBack = onBack,
                onSave = onSave,
                onDelete = onDelete
            )
        }

        FinalPage.MyIdentity -> with(args.identity) {
            MyIdentityScreen(
                initial = initial,
                saving = saving,
                loading = loading,
                error = error,
                onBack = onBack,
                onSave = onSave,
                onDelete = onDelete,
                onOpenVoiceModelSettings = onOpenVoiceModelSettings
            )
        }

        FinalPage.ContactMethods -> with(args.contactMethods) {
            FinalContactMethodsPageV3(
                entries = entries,
                selectedId = selectedId,
                onBack = onBack,
                onSelect = onSelect,
                onEdit = onEdit,
                onSetDefault = onSetDefault,
                onDeleteSelected = onDeleteSelected,
                onAdd = onAdd
            )
        }

        FinalPage.ContactMethodEdit -> with(args.contactEdit) {
            FinalContactMethodEditPageV3(
                args = AssistantContactMethodEditPageArgs(
                    state = AssistantContactMethodEditPageState(
                        mode = mode,
                        name = name,
                        gender = gender,
                        phone = phone,
                        error = error,
                        canDelete = mode == ContactEditMode.Edit && editingEntry?.isDefault == false,
                        deleteHint = if (mode == ContactEditMode.Edit && editingEntry?.isDefault == true) {
                            "默认联系方式不可直接删除，请先在列表中设置其他默认项。"
                        } else {
                            null
                        }
                    ),
                    callbacks = AssistantContactMethodEditPageCallbacks(
                        onBack = onBack,
                        onNameChange = onNameChange,
                        onGenderChange = onGenderChange,
                        onPhoneChange = onPhoneChange,
                        onDelete = onDelete,
                        onSave = onSave
                    )
                )
            )
        }

        else -> Unit
    }
}
