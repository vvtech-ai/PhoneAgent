package com.vvtech.aiassistant.uireference

import androidx.compose.runtime.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.Text
import androidx.compose.material.TextButton
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.vvtech.aiassistant.core.model.OptionItem
import com.vvtech.aiassistant.core.model.OptionsPayload
import com.vvtech.aiassistant.features.assistant.PureVoiceAgentOptionsCard

/** Actual options; callbacks update local display only. */
@Composable
fun OptionsReference() {
    var selected by remember { mutableStateOf<Int?>(null) }
    var generation by remember { mutableStateOf(0) }
    val options = OptionsPayload("请选择合成候选", listOf(
        OptionItem("synthetic-1", "合成餐厅", category = "restaurant", rating = 4.7,
            averageCostYuan = 88, cuisine = "粤菜", businessArea = "合成商圈",
            distanceMeters = 1250, openingStatus = "OPEN", openingHoursToday = "10:00–22:00"),
        OptionItem("synthetic-2", "合成未营业餐厅", openingStatus = "CLOSED")
    ))
    Column(Modifier.fillMaxSize()
        .background(Brush.verticalGradient(listOf(Color(0xFFF1F4FA), Color(0xFFE8EDF5))))
        .statusBarsPadding().verticalScroll(rememberScrollState())
        .padding(start = 18.dp, end = 18.dp, top = 200.dp)) {
        key(generation) {
            PureVoiceAgentOptionsCard(options, true, selected,
                onSelectIndex = { selected = it })
        }
        Text("合成已选：${selected?.let { "第 ${it + 1} 个" } ?: "无"}")
        TextButton(onClick = { selected = null; generation++ }) { Text("重置候选示例") }
    }
}
