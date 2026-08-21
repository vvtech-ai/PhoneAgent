package com.vvtech.aiassistant.features.assistant_contacts

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.Icon
import androidx.compose.material.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.DeleteOutline
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.features.assistant.ContactEditMode
import com.vvtech.aiassistant.features.assistant.FinalActionButton
import com.vvtech.aiassistant.features.assistant.FinalBackTitleBar
import com.vvtech.aiassistant.features.assistant.FinalGenderSelectorV3
import com.vvtech.aiassistant.features.assistant.FinalInputFieldV3
import com.vvtech.aiassistant.features.assistant.PersonalInfoGender
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText

internal data class AssistantContactMethodEditPageState(
    val mode: ContactEditMode,
    val name: String,
    val gender: PersonalInfoGender,
    val phone: String,
    val error: String?,
    val canDelete: Boolean,
    val deleteHint: String?
)

internal data class AssistantContactMethodEditPageCallbacks(
    val onBack: () -> Unit,
    val onNameChange: (String) -> Unit,
    val onGenderChange: (PersonalInfoGender) -> Unit,
    val onPhoneChange: (String) -> Unit,
    val onDelete: () -> Unit,
    val onSave: () -> Unit
)

internal data class AssistantContactMethodEditPageArgs(
    val state: AssistantContactMethodEditPageState,
    val callbacks: AssistantContactMethodEditPageCallbacks
)

@Composable
internal fun AssistantContactMethodEditPage(args: AssistantContactMethodEditPageArgs) {
    val state = args.state
    val callbacks = args.callbacks

    Column(modifier = Modifier.fillMaxSize()) {
        FinalBackTitleBar(
            title = if (state.mode == ContactEditMode.Edit) {
                currentAppText("编辑联系方式", "Edit Contact Method")
            } else {
                currentAppText("新增联系方式", "Add Contact")
            },
            onBack = callbacks.onBack
        )
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(start = 14.dp, end = 14.dp, bottom = 18.dp)
        ) {
            item {
                FinalInputFieldV3(
                    label = "Name",
                    value = state.name,
                    placeholder = "Enter name",
                    keyboardType = KeyboardType.Text,
                    onValueChange = callbacks.onNameChange
                )
            }
            item {
                FinalGenderSelectorV3(selected = state.gender, onSelect = callbacks.onGenderChange)
            }
            item {
                FinalInputFieldV3(
                    label = "Phone Number",
                    value = state.phone,
                    placeholder = "Example: 13800138000",
                    keyboardType = KeyboardType.Phone,
                    onValueChange = callbacks.onPhoneChange
                )
            }
            if (!state.error.isNullOrBlank()) {
                item {
                    Text(
                        text = state.error,
                        modifier = Modifier.padding(top = 10.dp),
                        color = Color(0xFFE14D46),
                        fontSize = 13.sp
                    )
                }
            }
            if (state.canDelete) {
                item {
                    AssistantContactMethodDeleteButton(onDelete = callbacks.onDelete)
                }
            } else if (!state.deleteHint.isNullOrBlank()) {
                item {
                    Text(
                        text = state.deleteHint,
                        modifier = Modifier.padding(top = 16.dp),
                        color = Color(0xFF98A2B3),
                        fontSize = 13.sp,
                        lineHeight = 20.sp
                    )
                }
            }
            item {
                FinalActionButton(
                    label = "Save",
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 18.dp),
                    onClick = callbacks.onSave
                )
            }
        }
    }
}

@Composable
private fun AssistantContactMethodDeleteButton(onDelete: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 16.dp)
            .clickable(onClick = onDelete),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = Icons.Rounded.DeleteOutline,
            contentDescription = null,
            tint = Color(0xFFE14D46),
            modifier = Modifier.size(18.dp)
        )
        Text(
            text = "Delete",
            color = Color(0xFFE14D46),
            fontSize = 14.sp,
            fontWeight = FontWeight.SemiBold
        )
    }
}
