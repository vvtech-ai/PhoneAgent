package com.vvtech.aiassistant.features.assistant_contacts

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.features.assistant.FinalBackTitleBar
import com.vvtech.aiassistant.features.assistant.FinalWideButtonV3
import com.vvtech.aiassistant.features.assistant.PersonalInfoEntry
import com.vvtech.aiassistant.features.assistant.displayLabel
import com.vvtech.aiassistant.features.assistant.maskPhone

@Composable
internal fun AssistantContactMethodsPage(
    entries: List<PersonalInfoEntry>,
    selectedId: String?,
    onBack: () -> Unit,
    onSelect: (String?) -> Unit,
    onEdit: (PersonalInfoEntry) -> Unit,
    onSetDefault: () -> Unit,
    onDeleteSelected: () -> Unit,
    onAdd: () -> Unit
) {
    val selectedEntry = selectedId?.let { id -> entries.firstOrNull { it.id == id } }
    val canDelete = selectedEntry != null && !selectedEntry.isDefault
    val canSetDefault = selectedEntry != null && !selectedEntry.isDefault

    Column(modifier = Modifier.fillMaxSize()) {
        FinalBackTitleBar(title = "Contact Methods", onBack = onBack)
        Box(modifier = Modifier.fillMaxSize()) {
            if (entries.isEmpty()) {
                AssistantContactMethodsEmptyState()
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(start = 14.dp, end = 14.dp, bottom = 120.dp)
                ) {
                    items(entries) { entry ->
                        AssistantContactMethodCard(
                            entry = entry,
                            selected = selectedId == entry.id,
                            showRadio = !entry.isDefault,
                            onSelect = { onSelect(if (selectedId == entry.id) null else entry.id) },
                            onEdit = { onEdit(entry) }
                        )
                    }
                }
            }

            Surface(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .fillMaxWidth()
                    .padding(horizontal = 14.dp, vertical = 14.dp)
                    .navigationBarsPadding(),
                color = Color.Transparent,
                elevation = 0.dp
            ) {
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    FinalWideButtonV3(
                        label = "Delete",
                        danger = true,
                        enabled = canDelete,
                        modifier = Modifier.weight(1f),
                        onClick = onDeleteSelected
                    )
                    FinalWideButtonV3(
                        label = "Set Default",
                        enabled = canSetDefault,
                        modifier = Modifier.weight(1f),
                        onClick = onSetDefault
                    )
                    FinalWideButtonV3(
                        label = "Add",
                        enabled = entries.size < 5,
                        modifier = Modifier.weight(1f),
                        onClick = onAdd
                    )
                }
            }
        }
    }
}

@Composable
private fun AssistantContactMethodsEmptyState() {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 14.dp, vertical = 16.dp),
        color = Color.White.copy(alpha = 0.80f),
        shape = RoundedCornerShape(24.dp),
        border = BorderStroke(1.dp, Color.White.copy(alpha = 0.78f)),
        elevation = 0.dp
    ) {
        Text(
            text = "No contact methods yet. Add one to use it in future tasks.",
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 16.dp),
            color = Color(0xFF6E6E73),
            fontSize = 13.sp,
            lineHeight = 18.sp
        )
    }
}

@Composable
private fun AssistantContactMethodCard(
    entry: PersonalInfoEntry,
    selected: Boolean,
    showRadio: Boolean,
    onSelect: () -> Unit,
    onEdit: () -> Unit
) {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 10.dp)
            .clickable(onClick = onEdit),
        color = if (entry.isDefault) Color(0xFFF5FAFF) else Color.White.copy(alpha = 0.80f),
        shape = RoundedCornerShape(22.dp),
        border = BorderStroke(1.dp, Color.White.copy(alpha = 0.78f)),
        elevation = 0.dp
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = "${entry.name} ${entry.gender.displayLabel()}",
                    color = Color(0xFF111111),
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = maskPhone(entry.phone),
                    modifier = Modifier.padding(top = 6.dp),
                    color = Color(0xFF6E6E73),
                    fontSize = 13.sp
                )
            }

            if (showRadio) {
                AssistantContactMethodRadio(selected = selected, onSelect = onSelect)
            } else {
                AssistantContactDefaultBadge()
            }
        }
    }
}

@Composable
private fun AssistantContactMethodRadio(
    selected: Boolean,
    onSelect: () -> Unit
) {
    Box(
        modifier = Modifier
            .size(18.dp)
            .clip(CircleShape)
            .border(1.8.dp, Color(0x3D3C3C43), CircleShape)
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClick = onSelect
            ),
        contentAlignment = Alignment.Center
    ) {
        if (selected) {
            Box(
                modifier = Modifier
                    .size(10.dp)
                    .background(Color(0xFF007AFF), CircleShape)
            )
        }
    }
}

@Composable
private fun AssistantContactDefaultBadge() {
    Surface(
        color = Color(0x1A007AFF),
        shape = RoundedCornerShape(999.dp),
        elevation = 0.dp
    ) {
        Text(
            text = "Default",
            modifier = Modifier.padding(horizontal = 9.dp, vertical = 5.dp),
            color = Color(0xFF007AFF),
            fontSize = 12.sp,
            fontWeight = FontWeight.ExtraBold
        )
    }
}
