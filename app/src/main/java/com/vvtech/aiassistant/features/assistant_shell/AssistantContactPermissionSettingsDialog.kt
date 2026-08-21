package com.vvtech.aiassistant.features.assistant_shell

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.AlertDialog
import androidx.compose.material.Text
import androidx.compose.material.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp

@Composable
internal fun AssistantContactPermissionSettingsDialog(
    onDismiss: () -> Unit,
    onOpenSettings: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Text(
                text = "Enable Contacts Permission",
                color = Color(0xFF111111),
                fontWeight = FontWeight.Bold
            )
        },
        text = {
            Text(
                text = "Contacts permission is disabled. Open app settings and enable Contacts to continue.",
                color = Color(0xFF6B7280)
            )
        },
        confirmButton = {
            TextButton(onClick = onOpenSettings) {
                Text("Open Settings", color = Color(0xFF2563EB), fontWeight = FontWeight.Bold)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel", color = Color(0xFF6B7280))
            }
        },
        shape = RoundedCornerShape(18.dp),
        backgroundColor = Color.White
    )
}
