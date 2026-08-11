package com.vvtech.aiassistant.features.assistant

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
@Composable
internal fun FinalAssistantRoleBubbleV3(
    text: String,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.Start
    ) {
        Surface(
            modifier = Modifier.fillMaxWidth(),
            color = Color.White.copy(alpha = 0.84f),
            shape = RoundedCornerShape(
                topStart = 22.dp,
                topEnd = 22.dp,
                bottomStart = 10.dp,
                bottomEnd = 22.dp
            ),
            border = BorderStroke(1.dp, Color.White.copy(alpha = 0.84f)),
            elevation = 0.dp
        ) {
            Column(modifier = Modifier.padding(horizontal = 16.dp, vertical = 14.dp)) {
                Text(
                    text = "Phone Agent",
                    color = Color(0xFF0A84FF),
                    fontSize = 11.sp,
                    fontWeight = FontWeight.ExtraBold
                )
                Text(
                    text = parseInlineMarkdown(text),
                    modifier = Modifier.padding(top = 6.dp),
                    color = Color(0xFF111111),
                    fontSize = 15.sp,
                    lineHeight = 22.sp
                )
            }
        }
    }
}

@Composable
internal fun FinalUserConfirmBubbleV3(
    text: String,
    showConfirm: Boolean,
    onConfirm: () -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.End
    ) {
        Surface(
            modifier = Modifier.widthIn(max = 296.dp),
            color = Color.Transparent,
            shape = RoundedCornerShape(
                topStart = 22.dp,
                topEnd = 22.dp,
                bottomStart = 22.dp,
                bottomEnd = 10.dp
            ),
            elevation = 0.dp
        ) {
            Column(
                modifier = Modifier
                    .background(
                        brush = Brush.verticalGradient(listOf(Color(0xFF0A84FF), Color(0xFF0071EB))),
                        shape = RoundedCornerShape(
                            topStart = 22.dp,
                            topEnd = 22.dp,
                            bottomStart = 22.dp,
                            bottomEnd = 10.dp
                        )
                    )
                    .padding(horizontal = 16.dp, vertical = 14.dp)
            ) {
                Text(
                    text = "确认",
                    color = Color.White.copy(alpha = 0.82f),
                    fontSize = 11.sp,
                    fontWeight = FontWeight.ExtraBold
                )
                Text(
                    text = text,
                    modifier = Modifier.padding(top = 6.dp),
                    color = Color.White,
                    fontSize = 15.sp,
                    lineHeight = 22.sp
                )
                if (showConfirm) {
                    Surface(
                        modifier = Modifier
                            .padding(top = 10.dp)
                            .align(Alignment.End)
                            .clickable(onClick = onConfirm),
                        color = Color.White.copy(alpha = 0.18f),
                        shape = RoundedCornerShape(14.dp),
                        elevation = 0.dp
                    ) {
                        Text(
                            text = "确认",
                            modifier = Modifier.padding(horizontal = 12.dp, vertical = 9.dp),
                            color = Color.White,
                            fontSize = 13.sp,
                            fontWeight = FontWeight.ExtraBold
                        )
                    }
                }
            }
        }
    }
}
