package com.vvtech.aiassistant.features.assistant_voice_clone.enrollment

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Icon
import androidx.compose.material.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Check
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.features.assistant.VoiceAccentBlue

@Composable
internal fun VoiceCloneAgreementRow(
    text: String,
    checked: Boolean,
    enabled: Boolean,
    modifier: Modifier = Modifier,
    onCheckedChange: (Boolean) -> Unit
) {
    Row(
        modifier = modifier.toggleable(
            value = checked,
            enabled = enabled,
            role = Role.Checkbox,
            onValueChange = onCheckedChange
        ),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.Top
    ) {
        VoiceCloneCheckIndicator(checked = checked, enabled = enabled)
        Text(
            text = text,
            modifier = Modifier.weight(1f),
            color = Color(0xFF374151),
            fontSize = 13.sp,
            lineHeight = 20.sp
        )
    }
}

@Composable
private fun VoiceCloneCheckIndicator(
    checked: Boolean,
    enabled: Boolean
) {
    val shape = RoundedCornerShape(3.dp)
    Box(
        modifier = Modifier
            .padding(top = 1.dp)
            .size(18.dp)
            .clip(shape)
            .background(
                when {
                    checked && enabled -> VoiceAccentBlue
                    checked -> VoiceAccentBlue.copy(alpha = 0.45f)
                    else -> Color.White
                }
            )
            .border(
                width = 1.dp,
                color = if (checked) VoiceAccentBlue else Color(0xFFB8BEC8),
                shape = shape
            ),
        contentAlignment = Alignment.Center
    ) {
        if (checked) {
            Icon(
                imageVector = Icons.Rounded.Check,
                contentDescription = null,
                modifier = Modifier.size(14.dp),
                tint = Color.White
            )
        }
    }
}
