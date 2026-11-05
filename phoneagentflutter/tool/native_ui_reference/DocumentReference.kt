package com.vvtech.aiassistant.uireference

import androidx.compose.runtime.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material.Text
import androidx.compose.material.TextButton
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.vvtech.aiassistant.features.assistant_large_task.LargeTaskDocument
import com.vvtech.aiassistant.features.assistant_large_task.LargeTaskDocumentFile
import com.vvtech.aiassistant.features.assistant_large_task.LargeTaskDocumentCard

/** Actual card; local display toggle only, no files, upload, account or SDK. */
@Composable
fun DocumentReference() {
    var parsing by remember { mutableStateOf(false) }
    Column(Modifier.fillMaxSize()
        .background(Brush.verticalGradient(listOf(Color(0xFFF1F4FA), Color(0xFFE8EDF5))))
        .statusBarsPadding().padding(start = 18.dp, end = 18.dp, top = 200.dp)) {
        LargeTaskDocumentCard(LargeTaskDocument(
            fileName = "", parsing = parsing,
            files = listOf(
                LargeTaskDocumentFile("合成任务资料.docx", charCount = 120),
                LargeTaskDocumentFile("合成迁移演练用联系人与参会时间安排清单.xlsx", charCount = 40, truncated = true)
            )
        ))
        Spacer(Modifier.height(12.dp))
        TextButton(onClick = { parsing = !parsing }) { Text("切换上传状态示例") }
    }
}
