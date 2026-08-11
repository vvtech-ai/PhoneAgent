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
                text = "开启通讯录权限",
                color = Color(0xFF111111),
                fontWeight = FontWeight.Bold
            )
        },
        text = {
            Text(
                text = "系统已关闭通讯录授权，请前往应用设置开启“通讯录”权限后继续。",
                color = Color(0xFF6B7280)
            )
        },
        confirmButton = {
            TextButton(onClick = onOpenSettings) {
                Text("去设置", color = Color(0xFF2563EB), fontWeight = FontWeight.Bold)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("取消", color = Color(0xFF6B7280))
            }
        },
        shape = RoundedCornerShape(18.dp),
        backgroundColor = Color.White
    )
}
