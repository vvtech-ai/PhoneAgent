package com.vvtech.aiassistant.features.assistant

import androidx.compose.runtime.Composable
import com.vvtech.aiassistant.features.assistant_contacts.AssistantContactMethodEditPage
import com.vvtech.aiassistant.features.assistant_contacts.AssistantContactMethodEditPageArgs
import com.vvtech.aiassistant.features.assistant_contacts.AssistantContactMethodsPage

@Composable
internal fun FinalContactMethodsPageV3(
    entries: List<PersonalInfoEntry>,
    selectedId: String?,
    onBack: () -> Unit,
    onSelect: (String?) -> Unit,
    onEdit: (PersonalInfoEntry) -> Unit,
    onSetDefault: () -> Unit,
    onDeleteSelected: () -> Unit,
    onAdd: () -> Unit
) {
    AssistantContactMethodsPage(
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

@Composable
internal fun FinalContactMethodEditPageV3(args: AssistantContactMethodEditPageArgs) {
    AssistantContactMethodEditPage(args = args)
}
