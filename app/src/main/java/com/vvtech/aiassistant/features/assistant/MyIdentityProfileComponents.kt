package com.vvtech.aiassistant.features.assistant

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.AlertDialog
import androidx.compose.material.Divider
import androidx.compose.material.Icon
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.DeleteOutline
import androidx.compose.material.icons.rounded.Edit
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.R
import com.vvtech.aiassistant.data.model.UserIdentityPayload

@Composable
internal fun MyIdentityProfileState(
    payload: UserIdentityPayload,
    status: UserIdentityDisplayStatus,
    saving: Boolean,
    onEdit: () -> Unit,
    onDelete: () -> Unit
) {
    val notAddedText = stringResource(R.string.settings_identity_status_not_set)
    val unspecifiedText = stringResource(R.string.identity_gender_unspecified)
    val genderValue = when (payload.gender?.trim().orEmpty()) {
        "男", "先生", "Mr.", "Mr" -> stringResource(R.string.identity_gender_mr)
        "女", "女士", "Ms.", "Ms" -> stringResource(R.string.identity_gender_ms)
        "", "不透露" -> unspecifiedText
        else -> payload.gender.orEmpty()
    }
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .shadow(
                elevation = 10.dp,
                shape = RoundedCornerShape(22.dp),
                ambientColor = Color.Black.copy(alpha = 0.08f),
                spotColor = Color.Black.copy(alpha = 0.08f)
            ),
        color = Color.White,
        shape = RoundedCornerShape(22.dp),
        border = BorderStroke(1.dp, Color.White.copy(alpha = 0.78f)),
        elevation = 0.dp
    ) {
        Column(Modifier.padding(18.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(stringResource(R.string.identity_section_profile), fontSize = 17.sp, fontWeight = FontWeight.Bold)
                    if (status == UserIdentityDisplayStatus.VERIFIED) {
                        MyIdentityVerifiedBadge()
                    }
                }
                Row(verticalAlignment = Alignment.CenterVertically) {
                    MyIdentityIconButton(
                        description = stringResource(R.string.identity_edit_content_description),
                        enabled = !saving,
                        onClick = onEdit
                    ) {
                        Icon(
                            Icons.Rounded.Edit,
                            contentDescription = null,
                            tint = Color(0xFF111111),
                            modifier = Modifier.size(21.dp)
                        )
                    }
                    MyIdentityIconButton(
                        description = stringResource(R.string.identity_delete_content_description),
                        enabled = !saving,
                        onClick = onDelete
                    ) {
                        Icon(
                            Icons.Rounded.DeleteOutline,
                            contentDescription = null,
                            tint = Color(0xFFE14D46),
                            modifier = Modifier.size(22.dp)
                        )
                    }
                }
            }
            MyIdentityDisplayRow(stringResource(R.string.identity_name_label), payload.name.orEmpty())
            MyIdentityDisplayRow(stringResource(R.string.identity_phone_label), payload.contactPhone?.takeIf(String::isNotBlank) ?: notAddedText)
            MyIdentityDisplayRow(stringResource(R.string.identity_gender_label), genderValue)
        }
    }
    Text(
        text = stringResource(R.string.identity_empty_description),
        modifier = Modifier.padding(top = 14.dp, start = 4.dp),
        color = Color(0xFF6E6E73),
        fontSize = 13.sp
    )
}
@Composable
private fun MyIdentityVerifiedBadge() {
    Surface(
        modifier = Modifier.padding(start = 8.dp),
        color = Color(0xFFEAF7EE),
        shape = RoundedCornerShape(999.dp),
        elevation = 0.dp
    ) {
        Text(
            stringResource(R.string.identity_verified),
            modifier = Modifier.padding(horizontal = 9.dp, vertical = 4.dp),
            color = Color(0xFF2E9D50),
            fontSize = 12.sp,
            fontWeight = FontWeight.Bold
        )
    }
}

@Composable
private fun MyIdentityIconButton(
    description: String,
    enabled: Boolean,
    onClick: () -> Unit,
    content: @Composable () -> Unit
) {
    Box(
        modifier = Modifier
            .size(42.dp)
            .semantics { contentDescription = description }
            .clickable(enabled = enabled, onClick = onClick),
        contentAlignment = Alignment.Center
    ) {
        content()
    }
}

@Composable
private fun MyIdentityDisplayRow(label: String, value: String) {
    Column {
        Divider(
            modifier = Modifier.padding(top = 12.dp),
            color = Color(0xFFE5E5EA),
            thickness = 1.dp
        )
        Row(
            modifier = Modifier.fillMaxWidth().padding(vertical = 12.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(label, color = Color(0xFF8E8E93), fontSize = 14.sp)
            Text(
                value,
                modifier = Modifier.padding(start = 18.dp),
                color = Color(0xFF1C1C1E),
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold
            )
        }
    }
}

@Composable
internal fun MyIdentityDeleteDialog(
    saving: Boolean,
    onDismiss: () -> Unit,
    onConfirm: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.identity_delete_title), fontWeight = FontWeight.Bold) },
        text = {
            Text(
                stringResource(R.string.identity_delete_message),
                lineHeight = 21.sp
            )
        },
        confirmButton = {
            Text(
                stringResource(R.string.identity_delete_title),
                color = Color(0xFFE14D46),
                fontWeight = FontWeight.Bold,
                modifier = Modifier
                    .clickable(enabled = !saving, onClick = onConfirm)
                    .padding(12.dp)
            )
        },
        dismissButton = {
            Text(
                stringResource(R.string.common_cancel),
                modifier = Modifier.clickable(enabled = !saving, onClick = onDismiss).padding(12.dp)
            )
        }
    )
}
