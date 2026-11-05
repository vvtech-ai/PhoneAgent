package com.vvtech.aiassistant.uireference

import androidx.compose.runtime.Composable
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.vvtech.aiassistant.core.model.BatchCallItemResultPayload
import com.vvtech.aiassistant.domain.task.ReceiptField
import com.vvtech.aiassistant.features.assistant_large_task.BatchPlusCallResultItem

/** Actual native item; no recording anchor, billing or business port. */
@Composable
fun BatchResultReference(withTranscript: Boolean = false) {
    Column(Modifier.fillMaxSize()
        .background(Brush.verticalGradient(listOf(Color(0xFFF1F4FA), Color(0xFFE8EDF5))))
        .statusBarsPadding().padding(start = 18.dp, end = 18.dp, top = 212.dp)) {
        Column(Modifier.width(308.dp)) {
            BatchPlusCallResultItem(
                item = BatchCallItemResultPayload(
                    itemId = "synthetic-result", targetName = "合成联系人", phoneNumber = "",
                    status = "SUCCESS", headline = "合成结果：已完成", detail = "",
                    attemptCount = 1, recalled = false, abnormal = false,
                    transcript = if (withTranscript) "assistant: 合成询问\ncallee: 合成答复" else null,
                    receiptFields = listOf(
                        ReceiptField("businessResult", "业务结果", "确认参加"),
                        ReceiptField("purpose", "事项", "合成评审")),
                ), onRecordingCardRevealed = {},
            )
        }
    }
}
