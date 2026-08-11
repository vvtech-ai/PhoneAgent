package com.vvtech.aiassistant.features.assistant

import androidx.compose.foundation.layout.padding
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vvtech.aiassistant.core.model.CallResultPayload
import com.vvtech.aiassistant.features.assistant_tasks.CallDisplayOutcome
import com.vvtech.aiassistant.features.assistant_tasks.callDisplayIsBookingScene
import com.vvtech.aiassistant.features.assistant_tasks.callResultOutcome
import com.vvtech.aiassistant.features.assistant_tasks.callResultStatusText

internal data class PureVoiceCallResultPresentation(
    val state: PureVoiceCallResultState,
    val style: PureVoiceCallResultStyle,
    val content: PureVoiceCallResultContent,
)

internal data class PureVoiceCallResultState(
    val structuredReceipt: Boolean,
    val bookingResult: Boolean,
    val pendingResult: Boolean,
    val failureResult: Boolean,
)

internal data class PureVoiceCallResultStyle(
    val title: String,
    val titleColor: Color,
    val borderColor: Color,
    val gradient: List<Color>,
)

internal data class PureVoiceCallResultContent(
    val resultStatus: String,
    val structuredRows: List<Pair<String, String>>,
    val bookingRows: List<Pair<String, String>>,
    val contactRows: List<Pair<String, String>>,
    val failureReason: String,
)

internal fun pureVoiceCallResultPresentation(
    sceneType: String?,
    summary: SummaryData?,
    data: CallPageData,
): PureVoiceCallResultPresentation {
    val notificationStatus = pureVoiceNotificationResultStatus(data.callResult)
    val semanticResult = data.callResult?.takeIf { notificationStatus == null }
    val structuredResult = semanticResult?.takeIf {
        receiptFieldDisplayRows(it.receiptFields).isNotEmpty()
    }
    val structuredRows = receiptFieldDisplayRows(structuredResult?.receiptFields)
    val structuredReceipt = structuredResult != null
    val bookingResult = notificationStatus == null && (
        structuredReceipt || callDisplayIsBookingScene(
            sceneType,
            pureVoiceCallResultSource(summary, data),
        )
    )
    val resultStatus = notificationStatus
        ?: semanticResult?.let { callResultStatusText(it, sceneType) }
        ?: pureVoiceCallResultStatus(sceneType, data)
    val pendingResult = pureVoiceCallResultPending(resultStatus)
    val partialResult = !pendingResult && pureVoiceCallResultPartial(resultStatus)
    val failureResult = !pendingResult && !partialResult && pureVoiceCallResultFailed(resultStatus)
    val bookingRows = if (bookingResult && !pendingResult && !failureResult) {
        pureVoiceBookingRows(sceneType, summary, data)
    } else {
        emptyList()
    }
    val contactRows = if (!failureResult && !partialResult && !pendingResult) {
        pureVoiceContactCallRows(summary, data)
    } else {
        emptyList()
    }
    val failureReason = pureVoiceFailureReason(data)
    return PureVoiceCallResultPresentation(
        state = PureVoiceCallResultState(
            structuredReceipt = structuredReceipt,
            bookingResult = bookingResult,
            pendingResult = pendingResult,
            failureResult = failureResult,
        ),
        style = PureVoiceCallResultStyle(
            title = when {
                pendingResult -> "结果确认中"
                bookingResult && partialResult -> "任务部分完成"
                bookingResult && !failureResult -> "任务完成"
                bookingResult -> "任务失败"
                else -> "执行结果"
            },
            titleColor = resultTitleColor(pendingResult, partialResult, failureResult),
            borderColor = resultBorderColor(pendingResult, partialResult, failureResult),
            gradient = resultGradient(pendingResult, partialResult, failureResult),
        ),
        content = PureVoiceCallResultContent(
            resultStatus = resultStatus,
            structuredRows = structuredRows,
            bookingRows = bookingRows,
            contactRows = contactRows,
            failureReason = failureReason,
        ),
    )
}

internal fun pureVoiceNotificationResultStatus(result: CallResultPayload?): String? {
    result ?: return null
    val headline = result.headline.filterNot(Char::isWhitespace)
    val successStatus = NotificationSuccessStatuses[headline]
    val recognizedNotification = successStatus != null || headline in NotificationFailureMarkers
    if (!recognizedNotification) return null
    val outcome = callResultOutcome(result)
    return if (
        successStatus != null &&
        (outcome == CallDisplayOutcome.Completed || outcome == CallDisplayOutcome.Unclear)
    ) {
        successStatus
    } else {
        "失败"
    }
}

@Composable
internal fun PureVoiceCallResultHeader(plan: PureVoiceCallResultPresentation) {
    Text(
        text = plan.style.title,
        color = plan.style.titleColor,
        fontSize = 14.sp,
        lineHeight = 18.sp,
        fontWeight = FontWeight.Bold,
    )
}

@Composable
internal fun PureVoiceCallResultBody(plan: PureVoiceCallResultPresentation) {
    when {
        plan.state.structuredReceipt -> {
            plan.content.structuredRows.forEach { (label, value) ->
                PureVoiceSummaryRow(label, value)
            }
            PureVoiceSummaryRow(
                label = "状态",
                value = if (plan.state.failureResult) plan.content.resultStatus else "✓任务完成",
                valueColor = plan.style.titleColor,
            )
        }
        plan.state.bookingResult && (plan.state.pendingResult || plan.state.failureResult) -> Text(
            text = plan.content.failureReason.ifBlank { plan.content.resultStatus },
            color = Color(0xFF333333),
            fontSize = 13.sp,
            lineHeight = 18.sp,
            modifier = Modifier.padding(top = 8.dp),
        )
        plan.state.bookingResult -> {
            plan.content.bookingRows.forEach { (label, value) -> PureVoiceSummaryRow(label, value) }
            PureVoiceSummaryRow("状态", "✓任务完成", valueColor = Color(0xFF34C759))
        }
        else -> {
            PureVoiceSummaryRow("状态", plan.content.resultStatus)
            plan.content.contactRows.forEach { (label, value) -> PureVoiceSummaryRow(label, value) }
            plan.content.failureReason.takeIf { plan.state.failureResult && it.isNotBlank() }?.let {
                PureVoiceSummaryRow("原因", it)
            }
        }
    }
}

private fun resultTitleColor(pending: Boolean, partial: Boolean, failure: Boolean): Color = when {
    pending || partial -> Color(0xFF8A6D1D)
    !failure -> Color(0xFF2E7D32)
    else -> Color(0xFFC62828)
}

private fun resultBorderColor(pending: Boolean, partial: Boolean, failure: Boolean): Color = when {
    pending || partial -> Color(0x33C99700)
    !failure -> Color(0x3334C759)
    else -> Color(0x33E14D46)
}

private fun resultGradient(pending: Boolean, partial: Boolean, failure: Boolean): List<Color> = when {
    pending || partial -> listOf(Color(0xFFFFF8E1), Color(0xFFFFE8A3))
    !failure -> listOf(Color(0xFFEDFAF0), Color(0xFFD6F5DC))
    else -> listOf(Color(0xFFFFF1F0), Color(0xFFFFDAD6))
}

private val NotificationSuccessStatuses = mapOf(
    "会议通知已送达" to "已通知",
    "挪车已通知车主" to "已通知车主",
    "挪车已通知物业" to "已通知物业",
    "挪车已通知保安" to "已通知保安",
    "挪车已通知停车场" to "已通知停车场",
    "挪车已通知公司前台" to "已通知公司前台",
    "挪车已通知114" to "已通知114",
    "挪车已通知122" to "已通知122",
)

private val NotificationFailureMarkers = setOf(
    "挪车通知失败",
    "会议通知失败",
)
