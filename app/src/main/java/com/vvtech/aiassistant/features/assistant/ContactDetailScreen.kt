package com.vvtech.aiassistant.features.assistant

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.Icon
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ArrowForward
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.R
import com.vvtech.aiassistant.data.model.ContactDirectoryEntry
import com.vvtech.aiassistant.data.model.ContactDirectoryUpsertRequest

internal val ContactPrimaryRelationOptions = listOf("家人", "同学", "同事", "客户", "商家", "其他")

@Composable
internal fun ContactDetailScreen(
    phone: String,
    initial: ContactDirectoryEntry?,
    saving: Boolean,
    loading: Boolean,
    error: String?,
    onBack: () -> Unit,
    onSave: (ContactDirectoryUpsertRequest) -> Unit,
    onDelete: (() -> Unit)? = null
) {
    var displayName by rememberSaveable(initial?.updatedAt) {
        mutableStateOf(initial?.displayName.orEmpty())
    }
    var primaryRelation by rememberSaveable(initial?.updatedAt) {
        mutableStateOf(initial?.primaryRelation.orEmpty())
    }
    var speakingStyle by rememberSaveable(initial?.updatedAt) {
        mutableStateOf(initial?.speakingStyle.orEmpty())
    }
    var description by rememberSaveable(initial?.updatedAt) {
        mutableStateOf(initial?.description.orEmpty())
    }
    var relationSheetVisible by rememberSaveable { mutableStateOf(false) }

    val canSave = remember(displayName, primaryRelation, speakingStyle, description, saving) {
        !saving && phone.isNotBlank()
    }

    Column(modifier = Modifier.fillMaxSize()) {
        FinalBackTitleBar(
            title = stringResource(R.string.contact_detail_title),
            onBack = onBack,
            trailing = {
                ContactDetailSaveButton(
                    enabled = canSave,
                    label = if (saving) {
                        stringResource(R.string.identity_saving)
                    } else {
                        stringResource(R.string.identity_save)
                    },
                    onClick = {
                        onSave(
                            ContactDirectoryUpsertRequest(
                                userId = "",
                                phone = phone,
                                displayName = displayName.trim().ifBlank { null },
                                primaryRelation = primaryRelation.trim().ifBlank { null },
                                speakingStyle = speakingStyle.trim().ifBlank { null },
                                description = description.trim().ifBlank { null }
                            )
                        )
                    }
                )
            }
        )

        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 18.dp, vertical = 12.dp)
        ) {
            if (loading) {
                MyIdentityHintCard(text = stringResource(R.string.contact_detail_loading))
                Spacer(Modifier.size(10.dp))
            }
            if (!error.isNullOrBlank()) {
                MyIdentityHintCard(text = error, danger = true)
                Spacer(Modifier.size(10.dp))
            }

            val noPhoneText = stringResource(R.string.contact_phone_not_set)
            ContactDetailCard {
                ContactDetailReadOnlyRow(
                    label = stringResource(R.string.contact_phone_label),
                    value = phone.ifBlank { noPhoneText }
                )
                ContactDetailDivider()
                MyIdentityRow(
                    label = stringResource(R.string.contact_name_label),
                    value = displayName,
                    placeholder = stringResource(R.string.contact_name_placeholder),
                    onValueChange = { displayName = it.take(128) }
                )
                ContactDetailDivider()
                ContactDetailRelationRow(
                    selected = primaryRelation,
                    onOpenSheet = { relationSheetVisible = true }
                )
            }

            Spacer(Modifier.size(18.dp))
            MyIdentitySectionTitle(stringResource(R.string.contact_speaking_style_title))
            Text(
                text = stringResource(R.string.contact_speaking_style_description),
                modifier = Modifier.padding(start = 4.dp, bottom = 8.dp),
                color = Color(0xFF6E6E73),
                fontSize = 12.sp
            )
            MyIdentityMultilineCard(
                value = speakingStyle,
                placeholder = stringResource(R.string.contact_speaking_style_placeholder),
                onValueChange = { speakingStyle = it.take(256) }
            )

            Spacer(Modifier.size(18.dp))
            MyIdentitySectionTitle(stringResource(R.string.contact_extra_description_title))
            Text(
                text = stringResource(R.string.contact_extra_description_description),
                modifier = Modifier.padding(start = 4.dp, bottom = 8.dp),
                color = Color(0xFF6E6E73),
                fontSize = 12.sp
            )
            MyIdentityMultilineCard(
                value = description,
                placeholder = stringResource(R.string.contact_extra_description_placeholder),
                onValueChange = { description = it.take(2000) }
            )

            Spacer(Modifier.size(24.dp))
            FinalActionButton(
                label = if (saving) stringResource(R.string.identity_saving) else stringResource(R.string.identity_save),
                tone = FinalButtonTone.Primary,
                enabled = canSave,
                modifier = Modifier
                    .fillMaxWidth(),
                onClick = {
                    onSave(
                        ContactDirectoryUpsertRequest(
                            userId = "",
                            phone = phone,
                            displayName = displayName.trim().ifBlank { null },
                            primaryRelation = primaryRelation.trim().ifBlank { null },
                            speakingStyle = speakingStyle.trim().ifBlank { null },
                            description = description.trim().ifBlank { null }
                        )
                    )
                }
            )

            if (onDelete != null && initial != null) {
                Spacer(Modifier.size(12.dp))
                FinalActionButton(
                    label = stringResource(R.string.contact_delete_action),
                    tone = FinalButtonTone.Danger,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(bottom = 32.dp),
                    onClick = onDelete
                )
            } else {
                Spacer(Modifier.size(32.dp))
            }
        }
    }

    if (relationSheetVisible) {
        ContactDetailRelationSheet(
            selected = primaryRelation,
            onSelect = {
                primaryRelation = it
                relationSheetVisible = false
            },
            onDismiss = { relationSheetVisible = false }
        )
    }
}

@Composable
private fun ContactDetailCard(content: @Composable () -> Unit) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        color = Color.White,
        shape = RoundedCornerShape(18.dp),
        border = BorderStroke(1.dp, Color(0x143C3C43)),
        elevation = 0.dp
    ) {
        Column { content() }
    }
}

@Composable
private fun ContactDetailDivider() {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .heightIn(min = 1.dp)
            .background(Color(0x143C3C43))
    )
}

@Composable
private fun ContactDetailReadOnlyRow(label: String, value: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 16.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(text = label, color = Color(0xFF111111), fontSize = 14.sp, fontWeight = FontWeight.Bold)
        Text(text = value, color = Color(0xFF6E6E73), fontSize = 15.sp)
    }
}

@Composable
private fun ContactDetailRelationRow(selected: String, onOpenSheet: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onOpenSheet)
            .padding(horizontal = 16.dp, vertical = 16.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = stringResource(R.string.contact_primary_relation_label),
            color = Color(0xFF111111),
            fontSize = 14.sp,
            fontWeight = FontWeight.Bold
        )
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = selected.takeIf { it.isNotBlank() }?.let { localizedContactRelation(it) }
                    ?: stringResource(R.string.contact_relation_choose),
                color = if (selected.isBlank()) Color(0xFF8E8E93) else Color(0xFF0A84FF),
                fontSize = 15.sp,
                fontWeight = FontWeight.Bold
            )
            Icon(
                imageVector = Icons.Outlined.ArrowForward,
                contentDescription = null,
                tint = Color(0xFF8E8E93),
                modifier = Modifier
                    .size(16.dp)
                    .padding(start = 4.dp)
            )
        }
    }
}

@Composable
private fun ContactDetailRelationSheet(
    selected: String,
    onSelect: (String) -> Unit,
    onDismiss: () -> Unit
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xCC000000))
            .clickable(onClick = onDismiss)
    ) {
        Surface(
            modifier = Modifier
                .fillMaxWidth()
                .align(Alignment.BottomCenter)
                .clickable {},
            color = Color.White,
            shape = RoundedCornerShape(topStart = 22.dp, topEnd = 22.dp),
            elevation = 0.dp
        ) {
            Column(modifier = Modifier.padding(start = 18.dp, end = 18.dp, top = 16.dp, bottom = 24.dp)) {
                Text(
                    text = stringResource(R.string.contact_relation_sheet_title),
                    color = Color(0xFF111111),
                    fontSize = 17.sp,
                    fontWeight = FontWeight.ExtraBold,
                    modifier = Modifier.padding(bottom = 12.dp)
                )
                ContactPrimaryRelationOptions.forEach { option ->
                    val active = option == selected
                    Surface(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 4.dp)
                            .clickable { onSelect(option) },
                        color = if (active) Color(0xFFE7F0FF) else Color(0xFFF7F8FA),
                        shape = RoundedCornerShape(12.dp),
                        elevation = 0.dp
                    ) {
                        Text(
                            text = localizedContactRelation(option),
                            modifier = Modifier.padding(horizontal = 16.dp, vertical = 14.dp),
                            color = if (active) Color(0xFF0A84FF) else Color(0xFF111111),
                            fontSize = 15.sp,
                            fontWeight = FontWeight.Bold
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun localizedContactRelation(option: String): String = when (option) {
    "家人" -> stringResource(R.string.contact_relation_family)
    "同学" -> stringResource(R.string.contact_relation_classmate)
    "同事" -> stringResource(R.string.contact_relation_colleague)
    "客户" -> stringResource(R.string.contact_relation_customer)
    "商家" -> stringResource(R.string.contact_relation_business)
    else -> stringResource(R.string.contact_relation_other)
}

@Composable
private fun ContactDetailSaveButton(enabled: Boolean, label: String, onClick: () -> Unit) {
    Surface(
        modifier = Modifier
            .heightIn(min = 32.dp)
            .clickable(enabled = enabled, onClick = onClick),
        color = if (enabled) Color(0xFF0A84FF) else Color(0xFFB8C0CC),
        shape = CircleShape,
        elevation = 0.dp
    ) {
        Text(
            text = label,
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 6.dp),
            color = Color.White,
            fontSize = 13.sp,
            fontWeight = FontWeight.Bold
        )
    }
}
