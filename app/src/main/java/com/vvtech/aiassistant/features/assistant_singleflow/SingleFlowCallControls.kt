package com.vvtech.aiassistant.features.assistant_singleflow

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
internal fun SfCallControlButton(
    modifier: Modifier = Modifier,
    title: String,
    icon: String,
    active: Boolean = false,
    danger: Boolean = false,
    onClick: () -> Unit
) {
    val background = when {
        danger -> Color(0x3DFF3B30)
        active -> Color(0x470A84FF)
        else -> Color.White.copy(alpha = 0.12f)
    }
    Surface(
        modifier = modifier
            .height(72.dp)
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(20.dp),
        color = background,
        border = BorderStroke(1.dp, Color.White.copy(alpha = if (danger) 0.22f else 0.14f))
    ) {
        Column(
            modifier = Modifier.fillMaxSize(),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(text = icon, fontSize = 22.sp, color = Color.White)
            Text(
                text = title,
                fontSize = 12.sp,
                color = Color.White.copy(alpha = 0.94f),
                modifier = Modifier.padding(top = 5.dp)
            )
        }
    }
}
