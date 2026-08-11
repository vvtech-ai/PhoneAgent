package com.vvtech.aiassistant.features.assistant_ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Button
import androidx.compose.material.ButtonDefaults
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog

@Composable
internal fun AssistantConfirmationDialog(
    title: String,
    message: String,
    dismissLabel: String,
    confirmLabel: String,
    onDismiss: () -> Unit,
    onConfirm: () -> Unit,
    dismissButtonModifier: Modifier = Modifier,
    confirmButtonModifier: Modifier = Modifier
) {
    Dialog(onDismissRequest = onDismiss) {
        Surface(
            modifier = Modifier
                .fillMaxWidth()
                .widthIn(max = 360.dp),
            color = Color.White,
            shape = RoundedCornerShape(20.dp),
            elevation = 16.dp
        ) {
            Column(
                modifier = Modifier.padding(
                    start = 20.dp,
                    top = 22.dp,
                    end = 20.dp,
                    bottom = 18.dp
                )
            ) {
                Text(
                    text = title,
                    color = Color(0xFF111827),
                    fontSize = 18.sp,
                    lineHeight = 25.sp,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = message,
                    modifier = Modifier.padding(top = 8.dp),
                    color = Color(0xFF667085),
                    fontSize = 14.sp,
                    lineHeight = 22.sp
                )
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 18.dp),
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    Button(
                        onClick = onDismiss,
                        modifier = dismissButtonModifier
                            .weight(1f)
                            .height(46.dp),
                        shape = RoundedCornerShape(13.dp),
                        colors = ButtonDefaults.buttonColors(
                            backgroundColor = Color(0xFFF0F3F7),
                            contentColor = Color(0xFF344054)
                        ),
                        elevation = ButtonDefaults.elevation(defaultElevation = 0.dp),
                        contentPadding = PaddingValues()
                    ) {
                        Text(
                            text = dismissLabel,
                            fontSize = 14.sp,
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                    Button(
                        onClick = onConfirm,
                        modifier = confirmButtonModifier
                            .weight(1f)
                            .height(46.dp),
                        shape = RoundedCornerShape(13.dp),
                        colors = ButtonDefaults.buttonColors(
                            backgroundColor = Color(0xFF168BFF),
                            contentColor = Color.White
                        ),
                        elevation = ButtonDefaults.elevation(defaultElevation = 0.dp),
                        contentPadding = PaddingValues()
                    ) {
                        Text(
                            text = confirmLabel,
                            fontSize = 14.sp,
                            fontWeight = FontWeight.Bold
                        )
                    }
                }
            }
        }
    }
}
