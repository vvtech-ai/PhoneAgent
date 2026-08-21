package com.vvtech.aiassistant.features.assistant_contacts

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Button
import androidx.compose.material.ButtonDefaults
import androidx.compose.material.OutlinedTextField
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.material.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.features.assistant_i18n.currentAppText

@Composable
internal fun AssistantContactRemarkEditor(
    initialRemark: String,
    saving: Boolean,
    error: String?,
    onDismiss: () -> Unit,
    onSave: (String) -> Unit
) {
    var draft by rememberSaveable(initialRemark) { mutableStateOf(initialRemark) }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0x380F0F12))
            .clickable(enabled = !saving, onClick = onDismiss),
        contentAlignment = Alignment.BottomCenter
    ) {
        Surface(
            modifier = Modifier
                .fillMaxWidth()
                .clickable(onClick = {})
                .imePadding(),
            color = Color(0xF5FFFFFF),
            shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp),
            elevation = 18.dp
        ) {
            Column(
                modifier = Modifier
                    .navigationBarsPadding()
                    .padding(horizontal = 20.dp, vertical = 18.dp)
            ) {
                Text(
                    text = "Edit Notes",
                    color = Color(0xFF111111),
                    fontSize = 21.sp,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = "AI will reference these notes when contacting this person.",
                    modifier = Modifier.padding(top = 5.dp),
                    color = Color(0xFF8E8E93),
                    fontSize = 13.sp
                )
                OutlinedTextField(
                    value = draft,
                    onValueChange = { value ->
                        if (value.length <= MAX_REMARK_LENGTH) draft = value
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 16.dp),
                    enabled = !saving,
                    minLines = 4,
                    maxLines = 8,
                    placeholder = { Text("Example: salutation, relationship, communication preferences") },
                    shape = RoundedCornerShape(18.dp)
                )
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 5.dp),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text(
                        text = error.orEmpty(),
                        color = Color(0xFFFF3B30),
                        fontSize = 12.sp
                    )
                    Text(
                        text = "${draft.length}/$MAX_REMARK_LENGTH",
                        color = Color(0xFF8E8E93),
                        fontSize = 12.sp
                    )
                }
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 14.dp),
                    horizontalArrangement = Arrangement.End,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    TextButton(onClick = onDismiss, enabled = !saving) {
                        Text("Cancel")
                    }
                    Button(
                        onClick = { onSave(draft) },
                        enabled = !saving,
                        modifier = Modifier.padding(start = 8.dp),
                        shape = RoundedCornerShape(16.dp),
                        colors = ButtonDefaults.buttonColors(backgroundColor = Color(0xFF0A84FF))
                    ) {
                        Text(
                            if (saving) currentAppText("保存中…", "Saving...") else currentAppText("保存", "Save"),
                            color = Color.White
                        )
                    }
                }
            }
        }
    }
}

private const val MAX_REMARK_LENGTH = 2000
