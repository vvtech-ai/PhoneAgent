package com.vvtech.aiassistant.features.assistant

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.R

private val SheetTextPrimary = Color(0xFF111111)
private val SheetTextSecondary = Color(0xFF6B7280)
private val SheetBlue = Color(0xFF0A84FF)
private val SheetCardBorder = Color(0xFFE8EDF3)
private val SheetSelectedBorder = Color(0xFF0A84FF)
private val SheetSelectedBg = Color(0xFFE8F2FF)

@Composable
fun AgentDeviceContactSelectionSheet(
    state: DeviceContactSelectionUiState,
    onConfirm: (Map<String, DeviceContactSelectionCandidateUi>) -> Unit,
    onCancel: () -> Unit
) {
    val selections = remember(state) {
        mutableStateMapOf<String, DeviceContactSelectionCandidateUi>().apply {
            state.groups.forEach { group ->
                group.candidates.firstOrNull()?.let { put(group.name, it) }
            }
        }
    }
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                Brush.verticalGradient(listOf(Color(0xFFF7FBFF), Color(0xFFEDF5FF))),
                RoundedCornerShape(22.dp)
            )
            .border(1.dp, Color(0xFFDCEBFF), RoundedCornerShape(22.dp))
            .padding(start = 16.dp, end = 16.dp, top = 18.dp, bottom = 16.dp)
    ) {
        Text(
            text = stringResource(R.string.contact_picker_title),
            color = SheetTextPrimary,
            fontSize = 16.sp,
            fontWeight = FontWeight.Bold
        )
        if (!state.reason.isNullOrBlank()) {
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = state.reason,
                color = SheetTextSecondary,
                fontSize = 13.sp
            )
        }
        Spacer(modifier = Modifier.height(12.dp))
        Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
            state.groups.forEach { group ->
                DeviceContactGroupCard(
                    group = group,
                    selected = selections[group.name],
                    onSelect = { candidate -> selections[group.name] = candidate }
                )
            }
        }
        Spacer(modifier = Modifier.height(14.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            ActionButton(
                text = stringResource(R.string.common_cancel),
                background = Color(0xFFF1F3F5),
                textColor = SheetTextPrimary,
                onClick = onCancel
            )
            ActionButton(
                text = stringResource(R.string.common_confirm),
                background = SheetBlue,
                textColor = Color.White,
                onClick = { onConfirm(selections.toMap()) }
            )
        }
    }
}

@Composable
private fun DeviceContactGroupCard(
    group: DeviceContactSelectionGroupUi,
    selected: DeviceContactSelectionCandidateUi?,
    onSelect: (DeviceContactSelectionCandidateUi) -> Unit
) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        color = Color.White,
        shape = RoundedCornerShape(16.dp),
        border = androidx.compose.foundation.BorderStroke(1.dp, SheetCardBorder),
        elevation = 0.dp
    ) {
        Column(modifier = Modifier.padding(14.dp)) {
            Text(
                text = group.name,
                color = SheetTextPrimary,
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold
            )
            Spacer(modifier = Modifier.height(8.dp))
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                group.candidates.forEachIndexed { index, candidate ->
                    val isSelected = selected != null &&
                        candidate.phoneNumber == selected.phoneNumber &&
                        candidate.contactId == selected.contactId
                    DeviceContactCandidateRow(
                        index = index,
                        candidate = candidate,
                        selected = isSelected,
                        onClick = { onSelect(candidate) }
                    )
                }
            }
        }
    }
}

@Composable
private fun DeviceContactCandidateRow(
    index: Int,
    candidate: DeviceContactSelectionCandidateUi,
    selected: Boolean,
    onClick: () -> Unit
) {
    val borderColor = if (selected) SheetSelectedBorder else SheetCardBorder
    val bgColor = if (selected) SheetSelectedBg else Color.White
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(bgColor, RoundedCornerShape(12.dp))
            .border(1.dp, borderColor, RoundedCornerShape(12.dp))
            .clickable(onClick = onClick)
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = "${index + 1}",
            color = SheetTextSecondary,
            fontSize = 13.sp
        )
        Spacer(modifier = Modifier.width(8.dp))
        Column {
            val nameLine = buildString {
                append(candidate.displayName)
                if (!candidate.label.isNullOrBlank()) append(" · ").append(candidate.label)
            }
            Text(
                text = nameLine,
                color = SheetTextPrimary,
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold
            )
            Text(
                text = candidate.phoneNumber,
                color = SheetTextSecondary,
                fontSize = 13.sp
            )
        }
    }
}

@Composable
private fun ActionButton(
    text: String,
    background: Color,
    textColor: Color,
    onClick: () -> Unit
) {
    Box(
        modifier = Modifier
            .height(40.dp)
            .background(background, RoundedCornerShape(20.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 22.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(text = text, color = textColor, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
    }
}
