package com.vvtech.aiassistant.features.assistant_singleflow

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.features.assistant.TaskReceiptCopyButton

@Composable
internal fun SfTaskReceiptOverlay(
    restaurantName: String,
    time: String,
    partySize: String,
    onDismiss: () -> Unit
) {
    val copyText = sfTaskReceiptCopyText(
        restaurantName = restaurantName,
        time = time,
        partySize = partySize
    )
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0x99000000))
            .clickable(onClick = onDismiss),
        contentAlignment = Alignment.Center
    ) {
        Surface(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 28.dp)
                .clickable(enabled = false, onClick = {}),
            shape = RoundedCornerShape(24.dp),
            color = Color.White,
            elevation = 16.dp
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 22.dp, vertical = 20.dp)
            ) {
                TaskReceiptHeader(copyText = copyText, onDismiss = onDismiss)
                Spacer(modifier = Modifier.height(18.dp))
                TaskReceiptStatusBadge()
                Spacer(modifier = Modifier.height(16.dp))
                ReceiptRow("任务类型", "餐厅预订")
                ReceiptRow("餐厅", restaurantName)
                ReceiptRow("时间", time)
                ReceiptRow("人数", partySize)
                ReceiptRow("结果", "已预订大厅座")
                ReceiptRow("包房", "已满")
                ReceiptRow("低消", "无")
                ReceiptRow("联系人", "李先生 139****9999")
            }
        }
    }
}

@Composable
private fun TaskReceiptHeader(
    copyText: String,
    onDismiss: () -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = "任务回执",
            color = Color(0xFF121A24),
            fontSize = 20.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.weight(1f)
        )
        TaskReceiptCopyButton(copyText = copyText)
        Spacer(modifier = Modifier.size(8.dp))
        Surface(
            modifier = Modifier
                .size(32.dp)
                .clickable(onClick = onDismiss),
            shape = CircleShape,
            color = Color(0xFFF2F4F7)
        ) {
            Box(contentAlignment = Alignment.Center) {
                Text(
                    text = "✕",
                    color = Color(0xFF6E788B),
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold
                )
            }
        }
    }
}

private fun sfTaskReceiptCopyText(
    restaurantName: String,
    time: String,
    partySize: String
): String {
    return listOf(
        "任务回执",
        "任务类型：餐厅预订",
        "餐厅：$restaurantName",
        "时间：$time",
        "人数：$partySize",
        "结果：已预订大厅座",
        "包房：已满",
        "低消：无",
        "联系人：李先生 139****9999"
    ).joinToString("\n")
}

@Composable
private fun TaskReceiptStatusBadge() {
    Surface(
        shape = RoundedCornerShape(999.dp),
        color = Color(0xFFE8F5E9)
    ) {
        Text(
            text = "✓ 已完成",
            color = Color(0xFF2E7D32),
            fontSize = 13.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 5.dp)
        )
    }
}

@Composable
private fun ReceiptRow(label: String, value: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 6.dp),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(
            text = label,
            color = Color(0xFF6E788B),
            fontSize = 14.sp
        )
        Text(
            text = value,
            color = Color(0xFF121A24),
            fontSize = 14.sp,
            fontWeight = FontWeight.Medium
        )
    }
}
