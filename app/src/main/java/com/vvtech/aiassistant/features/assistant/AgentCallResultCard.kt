package com.vvtech.aiassistant.features.assistant

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Icon
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.RemoveCircleOutline
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.core.model.CallResultPayload

private val ResultTextPrimary = Color(0xFF111111)
private val ResultTextSecondary = Color(0xFF6B7280)
private val ResultGreen = Color(0xFF18A957)
private val ResultRed = Color(0xFFE14D46)
private val ResultAmber = Color(0xFFB45309)
private val ResultGray = Color(0xFF9CA3AF)

@Composable
fun AgentCallResultCard(result: CallResultPayload) {
    val structuredReceipt = receiptFieldDisplayRows(result.receiptFields).isNotEmpty()
    if (structuredReceipt) {
        PureVoiceCallResultCard(
            sceneType = null,
            summary = null,
            data = CallPageData(
                name = result.metadata?.get("targetName").orEmpty(),
                sub = "",
                status = result.status,
                transcript = emptyList(),
                callResult = result,
            ),
        )
        return
    }
    val normalizedStatus = result.status.uppercase()
    val failedResult = normalizedStatus.contains("FAILED") ||
        normalizedStatus.contains("CANCEL") ||
        result.status.contains("失败") ||
        result.status.contains("未完成") ||
        result.status.contains("取消")
    val (statusColor, statusIcon) = when (normalizedStatus) {
        "COMPLETED", "UNCLEAR", "PARTIAL" -> ResultGreen to Icons.Rounded.Check
        "FAILED" -> ResultRed to Icons.Rounded.Close
        else -> ResultGray to Icons.Rounded.RemoveCircleOutline
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
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(
                imageVector = statusIcon,
                contentDescription = result.status,
                tint = statusColor,
                modifier = Modifier.size(22.dp)
            )
            Spacer(modifier = Modifier.width(8.dp))
            Text(
                text = result.headline,
                color = statusColor,
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.weight(1f)
            )
            if (!failedResult) {
                Spacer(modifier = Modifier.width(8.dp))
                TaskReceiptCopyButton(
                    copyText = callResultCopyText(result),
                    iconColor = statusColor
                )
            }
        }
        Spacer(modifier = Modifier.height(10.dp))
        Surface(
            modifier = Modifier.fillMaxWidth(),
            color = Color.White,
            shape = RoundedCornerShape(16.dp),
            border = androidx.compose.foundation.BorderStroke(1.dp, Color(0xFFE8EDF3)),
            elevation = 0.dp
        ) {
            Column(modifier = Modifier.padding(14.dp)) {
                Text(
                    text = result.detail,
                    color = ResultTextPrimary,
                    fontSize = 14.sp
                )
                if (!result.metadata.isNullOrEmpty()) {
                    Spacer(modifier = Modifier.height(8.dp))
                    result.metadata.forEach { (key, value) ->
                        Row(modifier = Modifier.padding(top = 2.dp)) {
                            Text(
                                text = key,
                                color = ResultTextSecondary,
                                fontSize = 12.sp
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = value,
                                color = ResultTextPrimary,
                                fontSize = 12.sp
                            )
                        }
                    }
                }
            }
        }
    }
}
