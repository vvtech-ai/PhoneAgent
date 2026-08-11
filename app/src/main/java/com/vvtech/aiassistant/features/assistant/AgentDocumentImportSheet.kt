package com.vvtech.aiassistant.features.assistant

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.CircularProgressIndicator
import androidx.compose.material.Icon
import androidx.compose.material.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Folder
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.core.model.DocumentImportRequestPayload

@Composable
fun AgentDocumentImportSheet(
    request: DocumentImportRequestPayload,
    importing: Boolean,
    onSelect: () -> Unit,
    onCancel: () -> Unit
) {
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
            text = request.title?.takeIf { it.isNotBlank() } ?: "上传文件",
            color = Color(0xFF111111),
            fontSize = 16.sp,
            fontWeight = FontWeight.Bold
        )
        request.reason?.takeIf { it.isNotBlank() }?.let { reason ->
            Text(
                text = reason,
                color = Color(0xFF6B7280),
                fontSize = 13.sp,
                modifier = Modifier.padding(top = 6.dp)
            )
        }
        Spacer(modifier = Modifier.height(14.dp))

        val dashColor = Color(0xFFB7C7DC)
        val cornerPx = with(androidx.compose.ui.platform.LocalDensity.current) { 16.dp.toPx() }
        val strokePx = with(androidx.compose.ui.platform.LocalDensity.current) { 1.5.dp.toPx() }
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(16.dp))
                .background(Color.White)
                .drawBehind {
                    drawRoundRect(
                        color = dashColor,
                        size = Size(size.width, size.height),
                        cornerRadius = CornerRadius(cornerPx, cornerPx),
                        style = Stroke(
                            width = strokePx,
                            pathEffect = PathEffect.dashPathEffect(floatArrayOf(14f, 10f), 0f)
                        )
                    )
                }
                .clickable(enabled = !importing, onClick = onSelect)
                .padding(horizontal = 18.dp, vertical = 22.dp),
            contentAlignment = Alignment.Center
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                if (importing) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(26.dp),
                        color = Color(0xFF0A84FF),
                        strokeWidth = 2.dp
                    )
                } else {
                    Icon(
                        imageVector = Icons.Filled.Folder,
                        contentDescription = null,
                        tint = Color(0xFFFFB020),
                        modifier = Modifier.size(28.dp)
                    )
                }
                Text(
                    text = if (importing) "正在解析文件" else "点击选择文件",
                    color = Color(0xFF111111),
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold
                )
                Text(
                    text = "支持 Markdown、TXT",
                    color = Color(0xFF6B7280),
                    fontSize = 12.sp
                )
            }
        }
    }
}
